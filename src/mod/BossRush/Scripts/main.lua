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
-- Bosses per 单挑 page. With 下一页 / 上一页 / 返回 a page has 11 rows, three more than the bell menu's own column
-- (8 with 强敌挑战), which it was laid out for; 54 bosses in a release build make 7 pages.
local PAGE = 8

-- Open bosses: not tied to level-placed points (or their points are placed by the mod), not prologue variants.
-- All are offered (user decision). Bosses still being tried ("testing") only in development builds.
local function offered(b)
    return b.state == "open" or (b.state == "testing" and config.debug)
end

local function available()
    local out = {}
    for _, b in ipairs(roster) do
        if offered(b) then out[#out + 1] = b end
    end
    return out
end

-- 单挑 list: the offered bosses and those fought at their original arena (单挑 only), in roster order, which is
-- the game's codex order: the order the player meets them (user request: list bosses by appearance).
local function duel_bosses()
    local out = {}
    for _, b in ipairs(roster) do
        if offered(b) or b.state == "origin" then out[#out + 1] = b end
    end
    return out
end

-- A gauntlet's bosses that are available right now (nil when fewer than two).
local function gauntlet_queue(g, avail)
    local ok = {}
    for _, b in ipairs(avail) do ok[b.id] = b end
    local q = {}
    if g.bosses == "all" then
        q = avail
    else
        for _, id in ipairs(g.bosses) do if ok[id] then q[#q + 1] = ok[id] end end
    end
    return #q >= 2 and q or nil
end

local show_root, show_bosses, show_gauntlets

-- Start a run. The arena is not chosen by the player: where they stand if it is a suitable arena,
-- otherwise a random suitable one (arenas.pick).
local function begin(queue, opts)
    local origin_of = #queue == 1 and queue[1].id or nil
    local pos
    pcall(function() pos = U.pawn():K2_GetActorLocation() end)
    local arena, in_place
    if #queue == 1 and queue[1].state == "origin" then
        -- Level-dependent boss: always its original arena.
        arena, in_place = arenas.origin_for(queue[1].id), false
    else
        arena, in_place = arenas.pick(origin_of, U.active_bells(), U.world_path(), pos, config.in_place_radius)
    end
    if not arena then U.log("no arena available") return end
    opts.in_place = in_place
    U.log("arena: %s (%s)", arena.key, in_place and "here" or "travel")
    menu.close()
    U.after(300, function() run.start(queue, U.game_difficulty(), arena, opts) end)
end

-- Page layout (user request): 下一页 / 上一页 first (both wrap around: 上一页 on the first page goes to the last),
-- then the bosses, then 返回. focus: the row to focus; 下一页 on entering (paging to find a boss is the common
-- action, user request), and after paging the paging row just used.
show_bosses = function(page, focus)
    local list = duel_bosses()
    if #list == 0 then
        menu.show({ { T("none"), function() end }, { T("back"), show_root } }, 1, show_root)
        return
    end
    local pages = math.max(1, math.ceil(#list / PAGE))
    page = math.min(math.max(page or 1, 1), pages)
    local items = {}
    if pages > 1 then
        items[#items + 1] = { T("next"), function() show_bosses(page % pages + 1, 1) end }
        items[#items + 1] = { T("prev"), function() show_bosses((page - 2) % pages + 1, 2) end }
    end
    for i = (page - 1) * PAGE + 1, math.min(page * PAGE, #list) do
        local b = list[i]
        -- Difficulty follows the game's own setting; records are kept per difficulty.
        local label = i18n.name(b)
        if b.state == "origin" then label = label .. " · " .. T("origin_tag") end
        items[#items + 1] = { label, function()
            begin({ b }, { record_key = "duel/" .. b.id .. "/" .. U.game_difficulty(), title = T("duel") .. " · " .. i18n.name(b) })
        end }
    end
    items[#items + 1] = { T("back"), show_root }
    menu.show(items, focus or 1, show_root)
end

show_gauntlets = function()
    local avail = available()
    local items = {}
    for _, g in ipairs(gauntlets) do
        local q = gauntlet_queue(g, avail)
        if q then
            items[#items + 1] = { string.format("%s · %d", i18n.name(g), #q), function()
                begin(q, { record_key = "gauntlet/" .. g.key .. "/" .. U.game_difficulty(), title = T("gauntlet") .. " · " .. i18n.name(g) })
            end }
        end
    end
    if #items == 0 then items[#items + 1] = { T("none"), function() end } end
    items[#items + 1] = { T("back"), show_root }
    menu.show(items, 1, show_root)
end

-- The third argument of menu.show is where the back key (Esc / gamepad B) goes: one level up.
show_root = function()
    menu.show({
        { T("duel"), function() show_bosses(1) end },
        { T("gauntlet"), show_gauntlets },
        -- 试炼 (Trial, the roguelike) is hidden until it is built.
        { T("back"), menu.restore },
    }, 1, menu.restore)
end

math.randomseed(os.time())
menu.install(show_root, function() return not run.active() end)
require("pause").install(run.active, run.abort)

-- Development only: autotest.lua is not shipped (src/tools/build_release.py leaves it out).
if config.debug then
    local ok, at = pcall(require, "autotest")
    if ok and at then at.install(run, arenas, roster) end
end
U.log("loaded (debug=%s, %d bosses in roster)", tostring(config.debug), #roster)
