local UEHelpers = require("UEHelpers")
local config = require("config")

local U = {}

function U.log(fmt, ...)
    if not config.debug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print("[BossRush] " .. (ok and msg or fmt) .. "\n")
end

-- Only for an object obtained in this same game-thread call (from a find, a property, a function result).
-- Never call it, or anything else, on an object kept from an earlier call: see U.ref.
function U.valid(o)
    return o ~= nil and o.IsValid ~= nil and o:IsValid()
end

-- Weak references. A Lua wrapper of a UObject is a raw pointer: once the game frees the object, every call on
-- the wrapper, IsValid included, reads freed memory. That crashed the game inside UE4SS
-- (UObjectBase::GetInternalIndex, four crash dumps) when a loop kept checking a closed bell menu.
-- So an object kept across calls (timers, loops, click handlers) is kept as a ref and looked up again by its
-- path each time: the engine's name lookup never returns an object that is unreachable or destroyed, and the
-- address check rejects a different object that took the same name.
function U.ref(o)
    if not U.valid(o) then return nil end
    local path = o:GetFullName():match("^%S+ (.+)$")
    -- Never hand StaticFindObject a non-string: UE4SS can crash natively building the argument error.
    if type(path) ~= "string" then U.log("ref: no path in %s", o:GetFullName()) return nil end
    local r = { path = path, addr = o:GetAddress() }
    if U.get(r) == nil then U.log("ref: %s cannot be looked up by path", tostring(path)) return nil end
    return r
end

-- The live object behind a ref, or nil once it is gone.
function U.get(r)
    if r == nil or type(r.path) ~= "string" then return nil end
    local ok, o = pcall(StaticFindObject, r.path)
    if ok and U.valid(o) and o:GetAddress() == r.addr then return o end
    return nil
end

function U.pawn()
    local pc = UEHelpers.GetPlayerController()
    return U.valid(pc) and pc.Pawn or nil
end

-- Whether any of the keys (FKey names, e.g. "Escape", "Gamepad_FaceButton_Right") is held right now.
function U.any_key_down(keys)
    local pc = UEHelpers.GetPlayerController()
    if not U.valid(pc) then return false end
    for _, k in ipairs(keys) do
        local ok, down = pcall(function() return pc:IsInputKeyDown({ KeyName = FName(k) }) end)
        if ok and down then return true end
    end
    return false
end

function U.world_path()
    local ok, p = pcall(function() return UEHelpers.GetWorld():GetFullName():match("(/Game/Maps/[^.]+)") end)
    return ok and p or nil
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

-- ---------------------------------------------------------------- entry points
-- Every call from the game into the mod goes through the functions below; no other file of the mod calls
-- ExecuteInGameThread, the delayed actions, RegisterHook, NotifyOnNewObject or RegisterKeyBind, and none calls
-- LoopAsync or ExecuteWithDelay (src/tools/lua_check.py enforces both). They guarantee that:
--   * mod code runs on the game thread only;
--   * an error never escapes: it is logged with its traceback, a loop that failed stops, and the mod turns
--     itself off (U.failed): no new entries in the game's menus, clicks on ours are ignored, the handlers
--     registered with U.on_fail clean up (a running challenge ends and the player is sent home), and the
--     player sees one line saying so. Timers already scheduled still run, so that clean-up can finish.
-- A native crash (e.g. touching a freed object, see U.ref) cannot be caught here; those are prevented by the
-- rules in AGENTS.md.
local failed = false
local fail_handlers = {}

function U.failed() return failed end

-- fn() runs once, on the game thread, when the mod turns itself off.
function U.on_fail(fn) fail_handlers[#fail_handlers + 1] = fn end

local function fail(err)
    print("[BossRush] ERROR " .. tostring(err) .. "\n")        -- always logged, debug or not
    if failed then return end
    failed = true
    for _, fn in ipairs(fail_handlers) do
        local ok, e = xpcall(fn, debug.traceback)
        if not ok then print("[BossRush] ERROR while stopping: " .. tostring(e) .. "\n") end
    end
    pcall(function() require("ui").toast(require("i18n").t("failed"), 6) end)
end

-- Calls fn(...) and turns an error into fail(). Returns ok, and fn's first result.
local function guarded(fn, ...)
    local ok, res = xpcall(fn, debug.traceback, ...)
    if not ok then fail(res) end
    return ok, res
end

-- Timers are UE4SS's delayed actions, which run entirely on the game thread. LoopAsync and ExecuteWithDelay
-- (used before 2026-11-14) run their callbacks on a separate thread inside the same Lua state as everything else:
-- with several loops going (run, menu, system-menu row, summons) the state got corrupted ("Ref was not function"
-- in the log, then "attempt to call a table value (for iterator)" on a plain `for ... in pairs(t)`), and the mod
-- stopped mid-challenge; an earlier Lua VM crash after hot reloads fits the same cause. Never use them.

-- fn() on the game thread after ms milliseconds (0: on the next game-thread tick).
function U.after(ms, fn)
    local function go() guarded(fn) end
    if ms <= 0 then ExecuteInGameThread(go) else ExecuteInGameThreadWithDelay(math.floor(ms), go) end
end

-- fn() on the game thread every ms milliseconds until it returns true or fails.
function U.every(ms, fn)
    local handle
    handle = LoopInGameThreadWithDelay(math.floor(ms), function()
        local ok, done = guarded(fn)
        if (not ok or done) and handle then CancelDelayedAction(handle) end
    end)
end

-- fn(obj) when an object of the class is created (in the call that creates it). Off once the mod has failed.
function U.on_new(class_path, fn)
    NotifyOnNewObject(class_path, function(obj)
        if not failed then guarded(fn, obj) end
    end)
end

-- fn(self, ...) after each call of a native function. Never a Blueprint function, never one that returns a
-- value (both crashed the game, AGENTS.md). Off once the mod has failed.
function U.hook(func_path, fn)
    RegisterHook(func_path, function(self, ...)
        if not failed then guarded(fn, self, ...) end
    end)
end

-- fn() on the game thread when the key is pressed (development tools). modifiers: optional list of
-- ModifierKey values, e.g. { ModifierKey.CONTROL }. F11 is the game's own key: never bind it.
function U.key(key, fn, modifiers)
    local function cb() U.after(0, fn) end
    if modifiers then RegisterKeyBind(key, modifiers, cb) else RegisterKeyBind(key, cb) end
end

-- Live instances of a class by its short name ("BP_X_C"), class default objects and everything inside them left
-- out. templates = true keeps objects inside a class default (not the default itself): a Blueprint's configured
-- parts, e.g. the actions of a gameplay ability, live there. The only way the mod calls FindAllOf (lua_check.py
-- enforces it): a non-string name is a Lua error here, where UE4SS's own argument check could crash natively
-- while building its message.
function U.find_all(class_short, templates)
    if type(class_short) ~= "string" then error("U.find_all: class name expected, got " .. type(class_short)) end
    local out = {}
    for _, o in ipairs(FindAllOf(class_short) or {}) do
        if U.valid(o) then
            local default = templates and o:GetFName():ToString():find("^Default__") or
                (not templates and o:GetFullName():find("Default__"))
            if not default then out[#out + 1] = o end
        end
    end
    return out
end

-- Load a class by "/Pkg/Path/Asset.Asset_C".
function U.load_class(path)
    if type(path) ~= "string" then error("U.load_class: path expected, got " .. type(path)) end
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

-- The game's own difficulty setting (EDifficultMode): 0 Handicapped, 1 Easy, 2 Normal, 3 Hard, 4 NightMare.
function U.game_difficulty()
    local d = 2
    pcall(function()
        local lib = StaticFindObject("/Script/ProjectPBZ.Default__PBZBlueprintFunctionLibrary")
        d = lib:GetDifficulty(require("UEHelpers").GetWorld())
    end)
    return tonumber(d) or 2
end

function U.bell_name(id)
    if id:find("^Bell") or id:find("^BrokenBell") then return id end
    return "Bell_" .. id
end

return U
