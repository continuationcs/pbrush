local UEHelpers = require("UEHelpers")
local config = require("config")

local U = {}

function U.log(fmt, ...)
    if not config.debug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print("[BossRush] " .. (ok and msg or fmt) .. "\n")
end

function U.valid(o)
    return o ~= nil and o.IsValid ~= nil and o:IsValid()
end

function U.pawn()
    local pc = UEHelpers.GetPlayerController()
    return U.valid(pc) and pc.Pawn or nil
end

function U.world_path()
    local ok, p = pcall(function() return UEHelpers.GetWorld():GetFullName():match("(/Game/Maps/[^.]+)") end)
    return ok and p or nil
end

-- "Class /Game/A/B.B_C" -> "/Game/A/B.B_C"
function U.obj_path(o)
    return (o:GetFullName():gsub("^%S+%s+", ""))
end

function U.text(s)
    return StaticFindObject("/Script/Engine.Default__KismetTextLibrary"):Conv_StringToText(s)
end

function U.dist(a, b)
    return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2)
end

function U.yaw_quat(deg)
    local r = math.rad(deg)
    return { X = 0, Y = 0, Z = math.sin(r / 2), W = math.cos(r / 2) }
end

function U.transform(x, y, z, yaw)
    return { Rotation = U.yaw_quat(yaw or 0), Translation = { X = x, Y = y, Z = z }, Scale3D = { X = 1, Y = 1, Z = 1 } }
end

-- Run fn on the game thread after ms milliseconds.
function U.after(ms, fn)
    ExecuteWithDelay(math.floor(ms), function() ExecuteInGameThread(function()
        local ok, err = pcall(fn)
        if not ok then U.log("error: %s", tostring(err)) end
    end) end)
end

-- Load a class by "/Pkg/Path/Asset.Asset_C".
function U.load_class(path)
    local c = StaticFindObject(path)
    if U.valid(c) then return c end
    pcall(LoadAsset, (path:gsub("%.[^.]+$", "")))
    c = StaticFindObject(path)
    if U.valid(c) then return c end
    local ok, res = pcall(function()
        local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        return ksl:LoadClassAsset_Blocking(ksl:Conv_SoftClassPathToSoftClassRef(ksl:MakeSoftClassPath(path)))
    end)
    c = StaticFindObject(path)
    if U.valid(c) then return c end
    if ok and U.valid(res) then return res end
    return nil
end

-- Bells the player has rung (BellManager.ActivateBellIDs), as a set of "Bell_XXX" names.
function U.active_bells()
    local set, n = {}, 0
    pcall(function()
        FindFirstOf("BellManager").ActivateBellIDs:ForEach(function(_, e)
            set[e:get():ToString()] = true
            n = n + 1
        end)
    end)
    return set, n
end

-- Enemies the player has defeated, from the game's codex subsystem. FindFirstOf can hand back the class
-- default object (empty), so every live instance is read. Sources, in order of preference:
--   EnemyKillMapIDs (enemy class path -> map where it fell), then RevealedEnemyPaths (identity revealed).
-- Returns a set keyed by class asset name ("BP_Monster_X_C" and "BP_Monster_X"), or nil when nothing
-- usable was found (callers then list every open boss).
local function soft_name(p)
    local name
    pcall(function() name = p.AssetPath.AssetName:ToString() end)
    if not name or name == "None" then pcall(function() name = p:ToString():match("([^./]+)$") end) end
    return name
end

function U.beaten()
    local best, best_n, best_src = nil, 0, "none"
    for _, cs in ipairs(FindAllOf("PBZCodexSubsystem") or {}) do
        if U.valid(cs) and not cs:GetFullName():find("Default__") then
            local kills, nk, revealed, nr = {}, 0, {}, 0
            pcall(function()
                cs.EnemyKillMapIDs:ForEach(function(k, v)
                    local name = soft_name(k:get())
                    if name then kills[name] = true nk = nk + 1 end
                end)
            end)
            pcall(function()
                cs.RevealedEnemyPaths:ForEach(function(_, e)
                    local name = soft_name(e:get())
                    if name then revealed[name] = true nr = nr + 1 end
                end)
            end)
            U.log("codex %s: %d kills, %d revealed", cs:GetFName():ToString(), nk, nr)
            if nk > best_n then best, best_n, best_src = kills, nk, "kills" end
            if nk == 0 and nr > best_n then best, best_n, best_src = revealed, nr, "revealed" end
        end
    end
    if not best or best_n == 0 then U.log("codex: no defeat record found, listing every open boss") return nil end
    -- Accept both "BP_X_C" and "BP_X" spellings.
    local set = {}
    for name in pairs(best) do
        set[name] = true
        set[(name:gsub("_C$", ""))] = true
        set[name .. "_C"] = true
    end
    local shown = 0
    for name in pairs(best) do
        shown = shown + 1
        if shown <= 3 then U.log("codex %s: %s", best_src, name) end
    end
    U.log("codex: %d defeated enemies (%s)", best_n, best_src)
    return set, best_n
end

-- The game's own difficulty setting (EDifficultMode): 0 Handicapped, 1 Easy, 2 Normal, 3 Hard, 4 NightMare.
function U.game_difficulty()
    local d = 2
    pcall(function()
        local lib = StaticFindObject("/Script/ProjectPBZ.Default__PBZBlueprintFunctionLibrary")
        d = lib:GetDifficulty(require("UEHelpers").GetWorld())
    end)
    return tonumber(d) or 2
end

-- "/Pkg/.../BP_X.BP_X_C" -> "BP_X_C"
function U.class_asset(path)
    return path:match("%.([^.]+)$")
end

function U.bell_name(id)
    if id:find("^Bell") or id:find("^BrokenBell") then return id end
    return "Bell_" .. id
end

-- Register a hook on a function declared by `cls_name` somewhere in `obj`'s class chain (Blueprint classes
-- have no fixed path we can hard-code, so it is resolved from a live object). Returns true when hooked.
local hooked = {}
function U.hook_in_chain(obj, cls_name, fn_name, cb)
    local c = obj:GetClass()
    while U.valid(c) do
        if c:GetFName():ToString() == cls_name then
            local path = U.obj_path(c) .. ":" .. fn_name
            if hooked[path] then return true end
            local ok, err = pcall(RegisterHook, path, cb)
            U.log("hook %s: %s", path, ok and "ok" or tostring(err))
            hooked[path] = ok
            return ok
        end
        c = c:GetSuperStruct()
    end
    return false
end

return U
