-- 强敌挑战 / Boss Challenge for Phantom Blade Zero.
-- Entry: the bell menu. Modes: 单挑 (Duel), 连战 (Gauntlet); 试炼 (Trial) hidden until it is built.
-- Design: docs/DESIGN.md, text: docs/COPY.md.
local U = require("util")
local i18n = require("i18n")
local config = require("config")
local menu = require("menu")
local run = require("run")
local arenas = require("arenas")
local roster = require("roster")
local gauntlets = require("gauntlets")

local T = i18n.t
local PAGE = 6

-- Open bosses (not tied to level-placed points, not prologue variants) the player may fight:
-- the defeated ones when beaten_only is on and the codex is readable, otherwise all open ones.
local function available()
    local beaten = config.beaten_only and U.beaten() or nil
    local out = {}
    for _, b in ipairs(roster) do
        if b.state == "open" then
            local asset = U.class_asset(b.class)
            if not beaten or beaten[asset] or beaten[b.id] then out[#out + 1] = b end
        end
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
    local arena, in_place = arenas.pick(origin_of, U.active_bells(), U.world_path(), pos, config.in_place_radius)
    if not arena then U.log("no arena available") return end
    opts.in_place = in_place
    U.log("arena: %s (%s)", arena.key, in_place and "here" or "travel")
    menu.close()
    U.after(300, function() run.start(queue, U.game_difficulty(), arena, opts) end)
end

show_bosses = function(page)
    local list = available()
    if #list == 0 then
        menu.show({ { T("none"), function() end }, { T("back"), show_root } })
        return
    end
    local pages = math.max(1, math.ceil(#list / PAGE))
    page = math.min(math.max(page or 1, 1), pages)
    local items = {}
    for i = (page - 1) * PAGE + 1, math.min(page * PAGE, #list) do
        local b = list[i]
        -- Difficulty follows the game's own setting; records are kept per difficulty.
        items[#items + 1] = { i18n.name(b), function()
            begin({ b }, { record_key = "duel/" .. b.id .. "/" .. U.game_difficulty(), title = T("duel") .. " · " .. i18n.name(b) })
        end }
    end
    if page > 1 then items[#items + 1] = { T("prev"), function() show_bosses(page - 1) end } end
    if page < pages then items[#items + 1] = { T("next"), function() show_bosses(page + 1) end } end
    items[#items + 1] = { T("back"), show_root }
    menu.show(items)
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
    menu.show(items)
end

show_root = function()
    i18n.detect()
    menu.show({
        { T("duel"), function() show_bosses(1) end },
        { T("gauntlet"), show_gauntlets },
        -- 试炼 (Trial, the roguelike) is hidden until it is built.
        { T("back"), menu.restore },
    })
end

math.randomseed(os.time())
i18n.detect()
menu.install(show_root, function() return not run.active() end)
require("pause").install(run.active, run.abort)
U.log("loaded (%s, debug=%s, %d bosses in roster)", i18n.zh and "zh" or "en", tostring(config.debug), #roster)
