-- Boss stats follow the player's progress (DESIGN §5.3).
-- A boss spawned by the mod has Level 0 and pure base stats; writing Level does not recompute anything,
-- but writing the attributes directly sticks. So: look up the game's own monster level curves and multiply.
local U = require("util")
local config = require("config")
local tiers = require("tier")

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

local function curve_path(name)
    return "/PBZCombatAsset/Config/Level/CV_AttributeCurve_Monster_" .. name .. ".CV_AttributeCurve_Monster_" .. name
end

-- Every curve's object path (the start-up check, health.lua, looks them up).
function M.curve_paths()
    local out = {}
    for name in pairs(CURVES) do out[#out + 1] = curve_path(name) end
    table.sort(out)
    return out
end

local function curve(name) return U.load(curve_path(name)) end

-- Progress level 1..25 (area levels run from Xigu 1 to Duanhun 25).
-- v1: share of bells rung. TODO: max area level of rung bells once bells are mapped to DT_AIAreaLevel areas.
local function progress_level()
    local _, n = U.active_bells()
    local lv = math.floor(25 * math.min(1, n / 170) + 0.5)
    return math.max(1, lv)
end

-- The playthrough (0 = first) from PBZGameSystem.CycleCount; 0 when it cannot be read.
local function cycle()
    return U.game_system("CycleCount") or 0
end

-- The game's monster curves repeat their shape every 25 levels (Health runs to level 500, Attack and Shachi to
-- 200; Attack's flat steps sit at 26-28, 51-53, 76-78 ...): each playthrough adds 25 levels to the area level
-- (user decision 2026-11-14, after a player saw 二周目 bosses at 25W health where the mod's had 15W). Capped at
-- the shortest curve's end.
local LEVELS_PER_CYCLE, MAX_LEVEL = 25, 200

local function target_level(difficulty)
    local lv = progress_level() + LEVELS_PER_CYCLE * cycle() + (config.difficulty_offset[difficulty] or 0)
    return math.min(lv, MAX_LEVEL)
end

-- Which tier multiplier (config.tiers) each curve's attributes also take; Infliction takes none.
-- ShachiAttack (破气, the boss's hits on the player's Sha-Chi) goes with attack (user decision 2026-11-14).
local TIER_FACTOR = { Health = "health", Shachi = "health", Attack = "attack", ShachiAttack = "attack" }

local function scale_attr(s, a, k)
    s[a].BaseValue = s[a].BaseValue * k
    s[a].CurrentValue = s[a].CurrentValue * k
end

-- How long a break lasts, the tier's only attribute without a level curve (user decision 2026-11-14).
-- BreakDurationAdditionalMultiplier is a term added to 1: most bosses read 0, 舞狮尊主's second phase -0.25 (a
-- shorter break by design, 2026-11-15), which no plain multiplier would be. The tier scales the resulting
-- duration: 1 + new = (1 + old) x break_time. (A faster Sha-Chi regeneration was tried and removed: ShachiRegen
-- read 0 on every boss and summon tested, so the game does not regenerate a boss's Sha-Chi through it.)
local function apply_break_time(s, f, parts)
    local a = s.BreakDurationAdditionalMultiplier
    local old = a.CurrentValue
    if f.break_time ~= 1 then
        local new = (1 + old) * f.break_time - 1
        a.BaseValue = a.BaseValue + (new - old)
        a.CurrentValue = new
    end
    parts[#parts + 1] = string.format("BreakDuration %+.2f -> %+.2f", old, a.CurrentValue)
end

-- ch: the boss, or one of its summons (scaled the same way, as the game levels both: a summon whose values the
-- game sizes from the boss's must follow the tier too); what: a name for the log (default: the boss).
-- difficulty: the game's EDifficultMode value (U.game_difficulty()); tier: 敌方强度 tier (tier.lua), 1 = 一重.
function M.apply(ch, difficulty, tier, what)
    local lv = target_level(difficulty)
    local f = tiers.factors(tier)
    local s = ch.AttributeSetBase
    local parts = {}
    for cname, attrs in pairs(CURVES) do
        local k = 1
        if config.scale_enabled then
            local cv = curve(cname)
            if cv then k = 1 + cv:GetFloatValue(lv) * config.curve_weight end
        end
        k = k * (f[TIER_FACTOR[cname]] or 1)
        if k ~= 1 then
            for _, a in ipairs(attrs) do pcall(scale_attr, s, a, k) end
        end
        parts[#parts + 1] = string.format("%s x%.2f", cname, k)
    end
    -- Read like the curve attributes: logged, not raised, if it cannot be.
    local ok, err = pcall(apply_break_time, s, f, parts)
    if not ok then parts[#parts + 1] = "break time failed: " .. tostring(err) end
    U.log("scale%s: level %d (progress %d, playthrough %d, difficulty %d, tier %d%s): %s", what and (" " .. what) or "",
        lv, progress_level(), cycle(), difficulty, tier, config.scale_enabled and "" or ", 原貌: curve off",
        table.concat(parts, ", "))
end

return M
