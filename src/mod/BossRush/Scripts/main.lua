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

local T = i18n.t
-- Rows per list page (单挑, 连战). With 下一页 / 上一页 / 返回 a page has 11 rows, three more than the bell menu's own column
-- (8 with 残影试炼), which it was laid out for; 66 bosses in a release build are 50 entries (later
-- phases are part of their boss's entry): 7 pages.
local PAGE = 8

-- Open bosses: not tied to level-placed points (or their points are placed by the mod), not prologue variants.
-- All are offered (user decision). Bosses still being tried ("testing") only in development builds.
local function offered(b)
    return b.state == "open" or (b.state == "testing" and config.debug)
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

-- A gauntlet's fights that are available right now (nil when fewer than two). Fights on a boss's own
-- battlefield are 单挑 only: a gauntlet stays in one arena.
local function gauntlet_queue(g, avail)
    local ok = {}
    for _, f in ipairs(avail) do
        if not own_boss(f) then ok[f.rec.id] = f end
    end
    local q = {}
    if g.bosses == "all" then
        for _, f in ipairs(avail) do if ok[f.rec.id] then q[#q + 1] = f end end
    else
        for _, id in ipairs(g.bosses) do if ok[id] then q[#q + 1] = ok[id] end end
    end
    return #q >= 2 and q or nil
end

local show_root, show_bosses, show_gauntlets, show_settings

-- Start a run (queue: fights). The arena is not chosen by the player: where they stand if it is a suitable
-- arena, otherwise a random suitable one (arenas.pick). opts.record: the record key without difficulty and tier.
-- Records are kept per game difficulty and 敌方强度 tier; 一重 adds nothing, so times from before tiers stay 一重's.
local function begin(queue, opts)
    local t = tier.get()
    opts.tier = t
    opts.record_key = opts.record .. "/" .. U.game_difficulty() .. (t > 1 and ("/t" .. t) or "")
    local origin_of = #queue == 1 and (own_boss(queue[1]) or queue[1].rec.id) or nil
    local pos
    pcall(function() pos = U.pawn():K2_GetActorLocation() end)
    local arena, in_place = arenas.pick(origin_of, U.active_bells(), U.world_path(), pos, config.in_place_radius)
    if not arena then
        -- Bound to its own battlefield, whose bell is not rung (arenas.pick logged it). The menu closes first so
        -- the notice is seen.
        local own = in_place
        U.log("no arena available")
        menu.close()
        if own then ui.toast(string.format(i18n.t("own_bell"), i18n.zh() and own.zh or own.en), 5) end
        return
    end
    opts.in_place, opts.origin_of = in_place, origin_of
    U.log("arena: %s (%s)", arena.key, in_place and "here" or "travel")
    menu.close()
    U.after(300, function() run.start(queue, U.game_difficulty(), arena, opts) end)
end

-- A list page (单挑, 连战). Layout (user request): 下一页 / 上一页 first (both wrap around: 上一页 on the first page
-- goes to the last), then PAGE rows, then 返回. rows = { {label, fn} }; reshow(page, focus) shows another page.
-- focus: the row to focus; "paging" = 下一页 when there are pages, else the first row. After paging, the paging
-- row just used keeps the focus.
local function show_paged(rows, page, focus, reshow)
    if #rows == 0 then
        menu.show({ { T("none"), function() end }, { T("back"), show_root, back = true } }, 1)
        return
    end
    local pages = math.max(1, math.ceil(#rows / PAGE))
    page = math.min(math.max(page or 1, 1), pages)
    local items = {}
    if pages > 1 then
        items[#items + 1] = { T("next"), function() reshow(page % pages + 1, 1) end }
        items[#items + 1] = { T("prev"), function() reshow((page - 2) % pages + 1, 2) end }
    end
    local first = #items + 1
    for i = (page - 1) * PAGE + 1, math.min(page * PAGE, #rows) do items[#items + 1] = rows[i] end
    items[#items + 1] = { T("back"), show_root, back = true }
    if focus == "paging" then focus = 1 elseif focus == nil then focus = first end
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
            begin({ f }, { record = key, mode = T("duel"), name = i18n.name(f.label) })
        end }
    end
    show_paged(rows, page, focus or "paging", show_bosses)
end

-- 连战: enters with the first group focused.
show_gauntlets = function(page, focus)
    local avail = available()
    local rows = {}
    for _, g in ipairs(gauntlets) do
        local q = gauntlet_queue(g, avail)
        if q then
            rows[#rows + 1] = { string.format("%s · %d", i18n.name(g), #q), function()
                begin(q, { record = "gauntlet/" .. g.key, mode = T("gauntlet"), name = i18n.name(g) })
            end }
        end
    end
    show_paged(rows, page, focus, show_gauntlets)
end

-- 设置: every player setting, one row each (user decision 2026-11-14: one page to grow into). A row that
-- cycles a value redraws the page and keeps its focus. Settings are the mod's own (settings.tsv), never the
-- game's or the save's.
local SETTINGS_ROW = 3     -- 设置's row on the root page, focused on the way back
show_settings = function(focus)
    menu.show({
        -- 敌方 · 强度 · 一重 … 五重 steps on each confirm (user decision 2026-11-14).
        { i18n.tier_row(tier.get()), function() tier.next() show_settings(1) end },
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
menu.install(show_root, function() return not run.active() end)
local pause = require("pause")
pause.install(run.active, run.abort)
run.on_start(pause.watch)

-- Development only: devtools.lua is not shipped (src/tools/build_release.py leaves it out).
if config.debug then
    local ok, dev = pcall(require, "devtools")
    if ok and dev then dev.install(run, arenas) end
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
