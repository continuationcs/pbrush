-- 「强敌挑战 · 退出挑战」 as a row of 系统 → 退出游戏 while a challenge runs: one press closes the menu and leaves
-- (counts as a defeat; user decision: no confirmation step).
--
-- That page is the game's settings panel (W_PBZSettingPanel_C, a UGameSettingPanel from the GameSettings plugin):
-- its rows are UGameSettingAction items of ListView_Settings (载入游戏 / 返回至开始界面 / 返回至桌面, whose
-- named actions UI.Setting.Exit.* the panel carries out); the panel's CurrentCollection is then "ExitCollection".
-- Our row is a UGameSettingAction of our own with no action bound, so the game's click does nothing with it; the
-- click reaches us through the one native button hook (widgets.lua) on the row's Button_Action. The page's list
-- is rebuilt whenever the page is shown, so while a challenge runs it is checked every CHECK_MS and the row is
-- added again; when the challenge ends the row is taken out.
local U = require("util")
local W = require("widgets")
local i18n = require("i18n")
local UEHelpers = require("UEHelpers")

local M = {}

local PANEL = "W_PBZSettingPanel_C"
local ENTRY = "W_SettingsListEntry_Action_C"          -- the row widget of an action setting
local ACTION_CLASS = "/Script/GameSettings.GameSettingAction"
local OWNER = "pause"
local CHECK_MS = 100
local EXIT_PAGE = "ExitCollection"          -- DevName of the 退出游戏 collection (seen in game, 2026-11-13)

-- panel full name -> { panel = ref, setting = ref }
local rows = {}
local last_page = nil          -- logged page layout (development log)

-- The objects of a TArray property (never an array returned by a call: see wire_entry).
local function objects(arr)
    local out = {}
    pcall(function()
        arr:ForEach(function(_, e)
            local ok, o = pcall(function() return e:get() end)
            out[#out + 1] = ok and o or e
        end)
    end)
    return out
end

-- The rows of the list: its ListItems property (GetListItems() returned nothing usable through UE4SS).
local function items_of(list)
    local ok, arr = pcall(function() return list.ListItems end)
    return ok and objects(arr) or {}
end

local function page_of(panel)
    local name = "?"
    pcall(function() name = panel.CurrentCollection:GetDevName():ToString() end)
    return name
end

local function class_name(o)
    return o:GetClass():GetFName():ToString()
end

local function same(a, b)
    return a ~= nil and b ~= nil and a:GetAddress() == b:GetAddress()
end

local function log_page(page, items)
    local parts = {}
    for _, it in ipairs(items) do
        local dev = "?"
        pcall(function() dev = it:GetDevName():ToString() end)
        parts[#parts + 1] = dev .. "(" .. class_name(it) .. ")"
    end
    local line = page .. ": " .. table.concat(parts, ", ")
    if line ~= last_page then
        last_page = line
        U.log("pause: settings page %s", line)
    end
end

local function new_setting(panel)
    local cls = StaticFindObject(ACTION_CLASS)
    if not U.valid(cls) then error("class not found: " .. ACTION_CLASS) end
    local s = StaticConstructObject(cls, panel)
    -- The fields a registered setting has; the entry and the details view may read them.
    pcall(function() s.OwningRegistry = panel.Registry end)
    pcall(function() s.LocalPlayer = UEHelpers.GetPlayerController().Player end)
    return s
end

-- Our row's entry widget on screen: label it, and route clicks on its button to us. Entries are found by class
-- and their reflected Setting property, never through an array returned by a call (GetDisplayedEntryWidgets):
-- with that, UE4SS later crashed while formatting an error for a FindAllOf call that had a string argument
-- (2026-11-13), which points at the returned array's memory.
local function wire_entry(row, ours, on_abort)
    for _, e in ipairs(U.find_all(ENTRY)) do
        local shown = nil
        pcall(function() shown = e.Setting end)
        if U.valid(shown) and same(shown, ours) then
            if not row.wired then row.wired = true U.log("pause: leave row on screen (%s)", class_name(e)) end
            local text = i18n.t("leave")
            for _, name in ipairs({ "SettingName", "Text_SettingName" }) do
                pcall(function()
                    local t = e[name]
                    if U.valid(t) and t:GetText():ToString() ~= text then t:SetText(U.text(text)) end
                end)
            end
            local btn = e.Button_Action
            if U.valid(btn) then
                local entry_ref = U.ref(e)
                W.on_click(btn, OWNER, function()
                    -- The list reuses entry widgets: act only if this one still shows our row.
                    local entry, setting = U.get(entry_ref), U.get(row.setting)
                    local now = nil
                    if entry then pcall(function() now = entry.Setting end) end
                    if not (setting and U.valid(now) and same(now, setting)) then return end
                    local panel = U.get(row.panel)
                    U.log("pause: leave chosen, closed %s", tostring(panel and W.close_screen(panel)))
                    U.after(200, on_abort)
                end)
            end
        end
    end
end

local function remove_row(key)
    local row = rows[key]
    rows[key] = nil
    local panel, setting = U.get(row.panel), U.get(row.setting)
    if panel and setting then pcall(function() panel.ListView_Settings:RemoveItem(setting) end) end
end

local function remove_all()
    for key in pairs(rows) do remove_row(key) end
    W.forget_owner(OWNER)
end

local function check_panel(panel, on_abort)
    local key = panel:GetFullName()
    local list = panel.ListView_Settings
    if not U.valid(list) then return end
    local row = rows[key]
    local ours = row and U.get(row.setting) or nil
    local items = items_of(list)
    local page = page_of(panel)
    log_page(page, items)
    local on_exit_page = page == EXIT_PAGE and #items > 0
    local listed = false
    for _, it in ipairs(items) do if same(it, ours) then listed = true end end
    if not on_exit_page then
        if listed then pcall(function() list:RemoveItem(ours) end) end
        return
    end
    if not ours then
        ours = new_setting(panel)
        row = { panel = U.ref(panel), setting = U.ref(ours) }
        rows[key] = row
    end
    if not listed then
        list:AddItem(ours)
        U.log("pause: leave row added to the exit page")
    end
    wire_entry(row, ours, on_abort)
end

-- is_active(): a challenge is running. on_abort(): leave it.
function M.install(is_active, on_abort)
    U.on_fail(remove_all)
    U.every(CHECK_MS, function()
        if not is_active() then
            if next(rows) then remove_all() U.log("pause: leave row removed (challenge over)") end
            return false
        end
        for _, p in ipairs(U.find_all(PANEL)) do
            if p:IsVisible() then check_panel(p, on_abort) end
        end
        for key, row in pairs(rows) do
            if not U.get(row.panel) then rows[key] = nil end            -- the panel is gone
        end
        return false
    end)
end

return M
