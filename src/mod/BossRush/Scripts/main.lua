-- 强敌挑战 / Boss Challenge for Phantom Blade Zero.
-- Entry: the bell menu. Modes: 单挑 (Duel), 连战 (Gauntlet); 试炼 (Trial) hidden until it is built.
-- Design: doc/DESIGN.md, text: doc/COPY.md.
local U = require("util")
local i18n = require("i18n")
local config = require("config")
local menu = require("menu")
local run = require("run")
local arenas = require("arenas")
local roster = require("roster")
local gauntlets = require("gauntlets")

local T = i18n.t
-- Rows per list page (单挑, 连战). With 下一页 / 上一页 / 返回 a page has 11 rows, three more than the bell menu's own column
-- (8 with 强敌挑战), which it was laid out for; 65 bosses in a release build are 51 entries (later
-- phases are part of their boss's entry): 7 pages.
local PAGE = 8

-- Open bosses: not tied to level-placed points (or their points are placed by the mod), not prologue variants.
-- All are offered (user decision). Bosses still being tried ("testing") only in development builds.
local function offered(b)
    return b.state == "open" or (b.state == "testing" and config.debug)
end

local by_id = {}
for _, b in ipairs(roster) do by_id[b.id] = b end

-- A boss with its later phases (roster `phases`; user decision 2026-11-14: one entry, phases fought straight on):
-- { rec = first phase, steps = { {rec}, {later phase's bosses}, ... } }. Later phases not offered are left out.
local function fight_of(b)
    local steps = { { b } }
    for _, ids in ipairs(b.phases or {}) do
        local step = {}
        for _, id in ipairs(ids) do
            local r = by_id[id]
            if r and offered(r) then step[#step + 1] = r end
        end
        if #step > 0 then steps[#steps + 1] = step end
    end
    return { rec = b, steps = steps }
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

local show_root, show_bosses, show_gauntlets

-- Start a run (queue: fights). The arena is not chosen by the player: where they stand if it is a suitable
-- arena, otherwise a random suitable one (arenas.pick).
local function begin(queue, opts)
    local origin_of = #queue == 1 and (own_boss(queue[1]) or queue[1].rec.id) or nil
    local pos
    pcall(function() pos = U.pawn():K2_GetActorLocation() end)
    local arena, in_place = arenas.pick(origin_of, U.active_bells(), U.world_path(), pos, config.in_place_radius)
    if not arena then U.log("no arena available") return end
    opts.in_place = in_place
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
        -- Difficulty follows the game's own setting; records are kept per difficulty. A boss fought in several
        -- phases keeps its time under its own key: times from when its first phase was fought alone do not count.
        local key = "duel/" .. b.id .. (#f.steps > 1 and "/all-phases" or "") .. "/" .. U.game_difficulty()
        rows[#rows + 1] = { i18n.name(b), function()
            begin({ f }, { record_key = key, title = T("duel") .. " · " .. i18n.name(b) })
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
                begin(q, { record_key = "gauntlet/" .. g.key .. "/" .. U.game_difficulty(), title = T("gauntlet") .. " · " .. i18n.name(g) })
            end }
        end
    end
    show_paged(rows, page, focus, show_gauntlets)
end

-- Every page's 返回 row is marked back = true: the back key (Esc / gamepad B) clicks it, one level up.
show_root = function()
    menu.show({
        { T("duel"), function() show_bosses(1) end },
        { T("gauntlet"), show_gauntlets },
        -- 试炼 (Trial, the roguelike) is hidden until it is built.
        { T("back"), menu.restore, back = true },
    }, 1)
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
        require("ui").toast("强敌挑战 已载入（开发版）" .. stamp, 3)
        return true
    end)
end
U.log("loaded (debug=%s, %d bosses in roster)", tostring(config.debug), #roster)
