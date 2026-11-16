-- 残影试炼 / Trial of Echoes (until 2026-11-14 强敌挑战 / Boss Challenge) for Phantom Blade Zero.
-- Entry: the bell menu. Modes: 单挑 (Duel), 连战 (Gauntlet); 万象 (Myriad, the roguelike) hidden until it is built.
-- Design: doc/DESIGN.md, text: doc/COPY.md.
local U = require("util")
local i18n = require("i18n")
local config = require("config")
local menu = require("menu")
local run = require("run")
local arenas = require("arenas")
local roster = require("roster")
local gauntlets = require("gauntlets")
local tier = require("tier")
local ui = require("ui")
local health = require("health")

local T = i18n.t
-- Rows per list page (单挑, 连战). With 下一页 / 上一页 / 返回 a page has 11 rows, three more than the bell menu's own column
-- (8 with 残影试炼), which it was laid out for; 66 bosses in a release build are 50 entries (later
-- phases are part of their boss's entry): 7 pages.
local PAGE = 8

-- Open bosses: not tied to level-placed points (or their points are placed by the mod), not prologue variants.
-- All are offered (user decision). Bosses still being tried ("testing") only in development builds. A boss whose
-- class or helper points the start-up check did not find in the game (an update, health.lua) is left out.
local function offered(b)
    return (b.state == "open" or (b.state == "testing" and config.debug)) and health.boss_ok(b)
end

local by_id = {}
for _, b in ipairs(roster) do by_id[b.id] = b end

-- A boss with its later phases (roster `phases`; user decision 2026-11-14: one entry, phases fought straight on)
-- and the bosses that appear with it from the start (roster `together`, in spawn order; 玉妖 and 铁鬼, user decision
-- 2026-11-15): { rec = the entry's boss, label = { zh, en } (the entry's name), steps = { {first step's bosses},
-- {later phase's bosses}, ... } }. Bosses not offered are left out.
local function fight_of(b)
    local first = {}
    for _, id in ipairs(b.together or { b.id }) do
        local r = by_id[id]
        if r and (r == b or offered(r)) then first[#first + 1] = r end
    end
    local label = { zh = b.zh, en = b.en }
    if #first > 1 then label = { zh = b.fight_zh, en = b.fight_en } end
    local steps = { first }
    for _, ids in ipairs(b.phases or {}) do
        local step = {}
        for _, id in ipairs(ids) do
            local r = by_id[id]
            if r and offered(r) then step[#step + 1] = r end
        end
        if #step > 0 then steps[#steps + 1] = step end
    end
    return { rec = b, label = label, steps = steps }
end

-- The boss of the fight that is fought only on its own battlefield (arenas.own), if any: the whole fight goes
-- there (舞狮尊主's first phase follows its second).
local function own_boss(f)
    for _, step in ipairs(f.steps) do
        for _, r in ipairs(step) do
            if arenas.own(r.id) then return r.id end
        end
    end
    return nil
end

-- Every boss on offer as a fight, in roster order, which is the game's codex order: the order the player meets
-- them (user request: 单挑 lists bosses by appearance). Later phases are part of their boss's fight.
local function available()
    local out = {}
    for _, b in ipairs(roster) do
        if offered(b) and not b.part_of then out[#out + 1] = fight_of(b) end
    end
    return out
end

-- A gauntlet's (or 千影 stage's) fights that are available right now, and the boss among them fought on its own
-- battlefield, if any: the run goes there while its bell is rung (DESIGN §5.0b). nil when fewer than two fights.
-- A boss bound to its battlefield (舞狮尊主) is left out while that bell is not rung. A run stays in one arena, so
-- a group holds at most one boss with an own battlefield: a second one is left out (and logged: a data mistake).
local function gauntlet_queue(g, avail, rung)
    local by = {}
    for _, f in ipairs(avail) do by[f.rec.id] = f end
    local q, own = {}, nil
    for _, id in ipairs(g.bosses) do
        local f = by[id]
        local oid = f and own_boss(f)
        local a = oid and arenas.own(oid)
        if f and not (a and a.bound and not arenas.usable(a, rung)) then
            if oid and own then
                U.log("gauntlet %s: %s left out, %s already has the group's own battlefield", i18n.name(g), id, own)
            else
                q[#q + 1] = f
                own = own or oid
            end
        end
    end
    if #q < 2 then return nil end
    return q, own
end

local show_root, show_bosses, show_gauntlets, show_stages, show_settings

-- Start a run (queue: fights). The arena is picked by arenas.pick (spec: what it is chosen by, see there) as the
-- 战斗 · 场地 setting says (自动 / 就近 / 随机, DESIGN §5.0c). opts.record: the record key without difficulty and tier.
-- Records are kept per game difficulty and 敌方强度 tier; 一重 adds nothing, so times from before tiers stay 一重's.
local function begin(queue, opts, spec)
    local t = tier.get()
    opts.tier = t
    opts.record_key = opts.record .. "/" .. U.game_difficulty() .. (t > 1 and ("/t" .. t) or "")
    local pos
    pcall(function() pos = U.pawn():K2_GetActorLocation() end)
    spec.mode = arenas.mode()
    local arena, in_place = arenas.pick(spec, U.active_bells(), U.world_path(), pos, config.in_place_radius)
    if not arena then
        -- Bound to its own battlefield, whose bell is not rung (arenas.pick logged it): no run, the menu closes
        -- and a notice says why.
        local own = in_place
        U.log("no arena available")
        menu.close()
        if own then ui.toast(string.format(i18n.t("own_bell"), i18n.zh() and own.zh or own.en), 5) end
        return
    end
    opts.in_place, opts.arena_spec = in_place, spec
    U.log("arena: %s (%s; setting %s, boss %s, group arena %s)", arena.key, in_place and "in-level move" or "travel",
        spec.mode, tostring(spec.boss), tostring(spec.prefer))
    menu.close()
    U.after(300, function() run.start(queue, U.game_difficulty(), arena, opts) end)
end

-- A list page (单挑, 连战). Layout (user request): 下一页 / 上一页 first (both wrap around: 上一页 on the first page
-- goes to the last), then PAGE rows, then 返回. rows = { {label, fn} }; reshow(page, focus) shows another page.
-- focus: the item to focus; "paging" = 下一页 when there are pages, else the first row; { row = n } = rows[n],
-- on its page (coming back from a sub-page). After paging, the paging row just used keeps the focus.
local function show_paged(rows, page, focus, reshow)
    if #rows == 0 then
        menu.show({ { T("none"), function() end }, { T("back"), show_root, back = true } }, 1)
        return
    end
    local pages = math.max(1, math.ceil(#rows / PAGE))
    local row = type(focus) == "table" and math.min(math.max(focus.row, 1), #rows) or nil
    if row then page = math.ceil(row / PAGE) end
    page = math.min(math.max(page or 1, 1), pages)
    local items = {}
    if pages > 1 then
        items[#items + 1] = { T("next"), function() reshow(page % pages + 1, 1) end }
        items[#items + 1] = { T("prev"), function() reshow((page - 2) % pages + 1, 2) end }
    end
    local first = #items + 1
    for i = (page - 1) * PAGE + 1, math.min(page * PAGE, #rows) do items[#items + 1] = rows[i] end
    items[#items + 1] = { T("back"), show_root, back = true }
    if row then focus = first + row - (page - 1) * PAGE - 1
    elseif focus == "paging" then focus = 1 elseif focus == nil then focus = first end
    menu.show(items, focus)
end

-- 单挑: enters with 下一页 focused (paging to find a boss is the common action, user request).
show_bosses = function(page, focus)
    local rows = {}
    for _, f in ipairs(available()) do
        local b = f.rec
        -- A boss fought in several phases, or with others, keeps its time under its own key: times from when its
        -- first boss was fought alone do not count.
        local key = "duel/" .. b.id .. (#f.steps > 1 and "/all-phases" or "") .. (#f.steps[1] > 1 and "/together" or "")
        rows[#rows + 1] = { i18n.name(f.label), function()
            begin({ f }, { record = key, mode = T("duel"), name = i18n.name(f.label) }, { boss = own_boss(f) or b.id })
        end }
    end
    show_paged(rows, page, focus or "paging", show_bosses)
end

-- A gauntlet's row: "name · fights" (a 千影 stage's too); clicking starts the run.
local function gauntlet_row(g, q, own, record)
    return { string.format("%s · %d", i18n.name(g), #q), function()
        begin(q, { record = record, mode = T("gauntlet"), name = i18n.name(g) }, { boss = own, prefer = g.arena })
    end }
end

-- The stages of a group split in stages (千影归来) that can be fought now: { row, fights }.
local function stage_rows(g, avail, rung)
    local rows, fights = {}, 0
    for i, s in ipairs(g.stages) do
        local q, own = gauntlet_queue(s, avail, rung)
        if q then
            rows[#rows + 1] = gauntlet_row(s, q, own, "gauntlet/" .. g.key .. "/" .. i)
            fights = fights + #q
        end
    end
    return rows, fights
end

-- 连战: enters with 下一页 focused, like 单挑 (user request 2026-11-15). 千影归来 shows its fights in all stages and opens its stage page.
show_gauntlets = function(page, focus)
    local avail, rung = available(), U.active_bells()
    local rows = {}
    for _, g in ipairs(gauntlets) do
        if g.stages then
            local stages, fights = stage_rows(g, avail, rung)
            if #stages > 0 then
                local row = #rows + 1
                rows[row] = { string.format("%s · %d", i18n.name(g), fights), function() show_stages(g, row) end }
            end
        else
            local q, own = gauntlet_queue(g, avail, rung)
            if q then rows[#rows + 1] = gauntlet_row(g, q, own, "gauntlet/" .. g.key) end
        end
    end
    show_paged(rows, page, focus or "paging", show_gauntlets)
end

-- 千影归来's stages (DESIGN §5.0b), one page: nine stages and 返回 are 10 rows, within the 11 a list page has.
-- 返回 goes back to the 连战 page, on the 千影归来 row (row: its index there).
show_stages = function(g, row)
    local items = stage_rows(g, available(), U.active_bells())
    items[#items + 1] = { T("back"), function() show_gauntlets(nil, { row = row }) end, back = true }
    menu.show(items, 1)
end

-- 设置: every player setting, one row each (user decision 2026-11-14: one page to grow into). A row that
-- cycles a value redraws the page and keeps its focus. Settings are the mod's own (settings.lua), never the
-- game's or the save's.
local SETTINGS_ROW = 3     -- 设置's row on the root page, focused on the way back
show_settings = function(focus)
    menu.show({
        -- 敌方 · 强度 · 一重 … 五重 steps on each confirm (user decision 2026-11-14).
        { i18n.tier_row(tier.get()), function() tier.next() show_settings(1) end },
        -- 战斗 · 场地 · 自动 / 就近 / 随机, the same way (user decision 2026-11-16).
        { i18n.arena_row(arenas.mode()), function() arenas.next_mode() show_settings(2) end },
        { T("back"), function() show_root(SETTINGS_ROW) end, back = true },
    }, focus or 1)
end

-- Every page's 返回 row is marked back = true: the back key (Esc / gamepad B) clicks it, one level up.
show_root = function(focus)
    menu.show({
        { T("duel"), function() show_bosses(1) end },
        { T("gauntlet"), show_gauntlets },
        -- 万象 (Myriad, the roguelike; formerly 试炼) is hidden until it is built.
        { T("settings"), function() show_settings() end },
        { T("back"), menu.restore, back = true },
    }, focus or 1)
end

math.randomseed(os.time())
-- The bell entry appears once the start-up check has passed (doc/UPDATE.md); a failed check stops the mod.
health.start()
-- Entering from the bell menu (not coming back from a sub-page): on 66 Days (EDifficultMode 4, NightMare) a tip
-- strip asks the player to use another difficulty (user request 2026-11-16). Run deaths are kept from being game
-- deaths (run.lua health floor), but one the floor misses would cost days in the player's only save.
local NIGHTMARE = 4
local function enter()
    show_root()
    local d = U.game_difficulty()
    U.log("entry: difficulty %d", d)
    if d == NIGHTMARE then ui.toast(T("nightmare"), 6) end
end
menu.install(enter, function() return health.ready() and not run.active() end)
local pause = require("pause")
pause.install(run.active, run.abort)
run.on_start(pause.watch)

-- God mode (F1): development builds, or a release build with the author's switch file (god.lua).
local god = require("god")
god.install(config.debug or god.unlocked())

-- Development only: devtools.lua is not shipped (src/tools/build_release.py leaves it out).
if config.debug then
    local ok, dev = pcall(require, "devtools")
    if ok and dev then dev.install(run, arenas) end
    -- Group data check (DESIGN §5.0b): every open boss in some 千影 stage (a newly opened boss is placed by hand),
    -- every listed boss in the roster, every arena key known.
    local staged = {}
    for _, g in ipairs(gauntlets) do
        local parts = g.stages or { g }
        for _, s in ipairs(parts) do
            if s.arena and not arenas.get(s.arena) then U.log("check: %s names unknown arena %s", s.zh, s.arena) end
            for _, id in ipairs(s.bosses) do
                if not by_id[id] then U.log("check: %s names unknown boss %s", s.zh, id) end
                if g.stages then staged[id] = true end
            end
        end
    end
    for _, f in ipairs(available()) do
        if not staged[f.rec.id] then U.log("check: %s is in no 千影 stage", f.rec.id) end
    end
    -- A tip strip once the player is in the game, so a hot reload (Ctrl+R) can be seen to have worked; the time
    -- tells one reload from the next. At game start mods load before there is a player: it waits for one.
    local stamp = os.date("%H:%M:%S")
    U.every(1000, function()
        if not U.valid(U.pawn()) then return false end
        require("ui").toast("残影试炼 已载入（开发版）" .. stamp, 3)
        return true
    end)
end
U.log("loaded (debug=%s, %d bosses in roster)", tostring(config.debug), #roster)
