-- Boss stats follow the player's progress (DESIGN §5.3).
-- A boss spawned by the mod has Level 0 and pure base stats; writing Level does not recompute anything,
-- but writing the attributes directly sticks. So: look up the game's own monster level curves and multiply.
local U = require("util")
local config = require("config")

local M = {}

-- Which curve drives which attributes.
local CURVES = {
    Health       = { "Health_Max", "Health" },
    Attack       = { "Attack" },
    -- The current value too, as for Health: a boss starts with a full Sha-Chi gauge, and scaling only the
    -- maximum left it at 1/12 of full (player report, 0.1.4).
    Shachi       = { "Shachi_Max", "Shachi" },
    ShachiAttack = { "ShachiAttack" },
    Infliction   = { "Infliction_Max" },
}

local function curve(name)
    local path = "/PBZCombatAsset/Config/Level/CV_AttributeCurve_Monster_" .. name .. ".CV_AttributeCurve_Monster_" .. name
    local cv = StaticFindObject(path)
    if not U.valid(cv) then
        pcall(LoadAsset, (path:gsub("%.[^.]+$", "")))
        cv = StaticFindObject(path)
    end
    return U.valid(cv) and cv or nil
end

-- Progress level 1..25 (area levels run from Xigu 1 to Duanhun 25).
-- v1: share of bells rung. TODO: max area level of rung bells once bells are mapped to DT_AIAreaLevel areas.
function M.progress_level()
    local _, n = U.active_bells()
    local lv = math.floor(25 * math.min(1, n / 170) + 0.5)
    return math.max(1, lv)
end

-- The playthrough (0 = first) from PBZGameSystem.CycleCount; 0 when it cannot be read.
function M.cycle()
    local c = 0
    for _, gs in ipairs(U.find_all("PBZGameSystem")) do
        pcall(function() c = math.max(c, tonumber(gs.CycleCount) or 0) end)
    end
    return c
end

-- The game's monster curves repeat their shape every 25 levels (Health runs to level 500, Attack and Shachi to
-- 200; Attack's flat steps sit at 26-28, 51-53, 76-78 ...): each playthrough adds 25 levels to the area level
-- (user decision 2026-11-14, after a player saw 二周目 bosses at 25W health where the mod's had 15W). Capped at
-- the shortest curve's end.
local LEVELS_PER_CYCLE, MAX_LEVEL = 25, 200

function M.target_level(difficulty)
    local lv = M.progress_level() + LEVELS_PER_CYCLE * M.cycle() + (config.difficulty_offset[difficulty] or 0)
    return math.min(lv, MAX_LEVEL)
end

-- ch: the boss, or one of its summons (scaled the same way, as the game levels both); what: a name for the log
-- (default: the boss). difficulty: the game's EDifficultMode value (U.game_difficulty()).
function M.apply(ch, difficulty, what)
    if not config.scale_enabled then U.log("scale: off (原貌)") return end
    local lv = M.target_level(difficulty)
    local s = ch.AttributeSetBase
    local parts = {}
    for cname, attrs in pairs(CURVES) do
        local cv = curve(cname)
        if cv then
            local k = 1 + cv:GetFloatValue(lv) * config.curve_weight
            for _, a in ipairs(attrs) do
                pcall(function()
                    s[a].BaseValue = s[a].BaseValue * k
                    s[a].CurrentValue = s[a].CurrentValue * k
                end)
            end
            parts[#parts + 1] = string.format("%s x%.2f", cname, k)
        end
    end
    U.log("scale%s: level %d (progress %d, playthrough %d, difficulty %d): %s", what and (" " .. what) or "", lv,
        M.progress_level(), M.cycle(), difficulty, table.concat(parts, ", "))
    if not what then M.log_game_level_sources(ch) end
end

-- Development log, read only: what the game feeds into a native monster's level, to check the mod against it
-- (the playthrough is used since 2026-11-14; the difficulty offsets read 0 except Handicapped -1). A player reported bosses in a second playthrough (二周目) at 25W health where the mod's had 15W
-- (0.1.4): the playthrough count (PBZGameSystem.CycleCount), each difficulty config's Global Mob Level Offset
-- (PDA_GlobalCombatConfig, one per difficulty: GlobalConfig_Combined_<difficulty>), and the boss's own view:
-- BP_RenewalNPC reads the game cycle (GetGameCycle) and has a Level property, Init Level and GetCombatLevel.
function M.log_game_level_sources(boss)
    if not config.debug then return end
    local lv, combat = "?", "?"
    pcall(function() lv = string.format("%.2f", boss.Level) end)
    pcall(function() combat = tostring(boss:GetCombatLevel()) end)
    U.log("scale: boss Level property %s, GetCombatLevel %s", lv, combat)
    local cycles = {}
    for _, gs in ipairs(U.find_all("PBZGameSystem")) do
        pcall(function() cycles[#cycles + 1] = tostring(gs.CycleCount) end)
    end
    local offsets = {}
    for _, c in ipairs(U.find_all("PDA_GlobalConfig_Combined_C")) do
        local name, off = c:GetFName():ToString(), "?"
        pcall(function() off = string.format("%.2f", c["Combat Config"]["Global Mob Level Offset"]) end)
        offsets[#offsets + 1] = name .. " " .. off
    end
    U.log("scale: playthrough %s; global mob level offset: %s", table.concat(cycles, "/"),
        #offsets > 0 and table.concat(offsets, ", ") or "no config loaded")
    -- Native monsters in the loaded level carry the level the game gave them (area level plus whatever the
    -- playthrough and difficulty add): the nearest few, alive, with their level and health.
    local p = U.pawn()
    local at = p and p:K2_GetActorLocation()
    local found = {}
    for _, npc in ipairs(U.find_all("PBZCharacter_NPC")) do
        pcall(function()
            if npc:IsDead() then return end
            local s = npc.AttributeSetBase
            local lv = s.Level.CurrentValue
            if lv <= 0 then return end          -- spawned by the mod (our bosses have level 0)
            local l = npc:K2_GetActorLocation()
            found[#found + 1] = { d = at and U.dist(l, at) or 0, line = string.format("%s level %.0f health %.0f attack %.0f",
                npc:GetClass():GetFName():ToString(), lv, s.Health_Max.CurrentValue, s.Attack.CurrentValue) }
        end)
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    for i = 1, math.min(8, #found) do
        U.log("scale:   native %s, %.0f m away", found[i].line, found[i].d / 100)
    end
    if #found == 0 then U.log("scale:   no native monster loaded") end
end

return M
