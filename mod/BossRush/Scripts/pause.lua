-- 「收刃离去」 in the in-game menu while a challenge runs: first press asks for confirmation (the label
-- changes), second press leaves (counts as a defeat). The menu's widget layout was not in the header dump,
-- so the button list is found at runtime: the first VerticalBox holding the menu's own buttons.
local U = require("util")
local menu = require("menu")
local i18n = require("i18n")
local UEHelpers = require("UEHelpers")

local M = {}

local MENU_CLASS = "/Game/PBZContent/UI/Hud/WB_GameMenuV1.WB_GameMenuV1_C"

local function is_button(o)
    local ok, r = pcall(function()
        local c = o:GetClass()
        while U.valid(c) do
            if c:GetFName():ToString() == "CommonButtonBase" then return true end
            c = c:GetSuperStruct()
        end
        return false
    end)
    return ok and r
end

-- Buttons the menu holds as properties, in declaration order.
local function menu_buttons(w)
    local out = {}
    pcall(function()
        w:GetClass():ForEachProperty(function(p)
            local name = p:GetFName():ToString()
            local okv, v = pcall(function() return w[name] end)
            if okv and type(v) == "userdata" and U.valid(v) and is_button(v) then out[#out + 1] = { name = name, w = v } end
        end)
    end)
    return out
end

local function children(box)
    local out = {}
    for i = 0, box:GetChildrenCount() - 1 do out[#out + 1] = box:GetChildAt(i) end
    return out
end

local function inject(w, on_abort)
    local buttons = menu_buttons(w)
    local names = {}
    for _, b in ipairs(buttons) do names[#names + 1] = b.name end
    U.log("pause: menu buttons: %s", table.concat(names, ", "))
    -- First visible button that sits (directly or through wrappers) in a VerticalBox.
    local anchor, box
    for _, b in ipairs(buttons) do
        if b.w:IsVisible() then
            local a, p, guard = b.w, b.w:GetParent(), 0
            while U.valid(p) and p:GetClass():GetFName():ToString() ~= "VerticalBox" and guard < 6 do
                a, p, guard = p, p:GetParent(), guard + 1
            end
            if U.valid(p) then anchor, box = { btn = b.w, slot_widget = a }, p break end
        end
    end
    if not box then U.log("pause: no button column found") return end
    local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local mine = wbl:Create(w, anchor.btn:GetClass(), UEHelpers.GetPlayerController())
    -- Put ours first: take every child out, add ours, put them back with their slot settings.
    local kids = {}
    for _, c in ipairs(children(box)) do
        kids[#kids + 1] = { w = c, pad = c.Slot.Padding, h = c.Slot.HorizontalAlignment, v = c.Slot.VerticalAlignment }
    end
    for _, k in ipairs(kids) do box:RemoveChild(k.w) end
    box:AddChildToVerticalBox(mine)
    pcall(function()
        mine.Slot:SetPadding(anchor.slot_widget.Slot.Padding)
        mine.Slot:SetHorizontalAlignment(anchor.slot_widget.Slot.HorizontalAlignment)
    end)
    for _, k in ipairs(kids) do
        box:AddChildToVerticalBox(k.w)
        pcall(function() k.w.Slot:SetPadding(k.pad) k.w.Slot:SetHorizontalAlignment(k.h) k.w.Slot:SetVerticalAlignment(k.v) end)
    end
    menu.set_label(mine, i18n.t("abort"))
    local armed = false
    menu.bind(mine, function()
        if not armed then
            armed = true
            menu.set_label(mine, i18n.t("abort_confirm"))
            return
        end
        menu.unbind(mine)
        pcall(function() w:DeactivateWidget() end)
        U.after(200, on_abort)
    end)
    U.log("pause: 收刃离去 added")
end

-- is_active(): a challenge is running. on_abort(): leave it.
function M.install(is_active, on_abort)
    NotifyOnNewObject(MENU_CLASS, function(w)
        U.after(300, function()
            if not U.valid(w) or not is_active() then return end
            local ok, err = pcall(inject, w, on_abort)
            if not ok then U.log("pause inject failed: %s", tostring(err)) end
        end)
    end)
end

return M
