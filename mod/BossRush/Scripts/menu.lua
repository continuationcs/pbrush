-- Bell menu: adds 「强敌挑战」 below 穿行, and shows our pages in place of the menu's own options,
-- using the menu's own button class and button group, so look, sound and gamepad navigation are native.
local U = require("util")
local UEHelpers = require("UEHelpers")

local M = {}

local cur = nil          -- { menu, box, group, entry, hidden = {{w, vis}}, added = {widgets} }
local handlers = {}      -- button full name -> fn

local function children(box)
    local out = {}
    for i = 0, box:GetChildrenCount() - 1 do out[#out + 1] = box:GetChildAt(i) end
    return out
end

local function slot_copy(from, to)
    pcall(function()
        to.Slot:SetPadding(from.Slot.Padding)
        to.Slot:SetHorizontalAlignment(from.Slot.HorizontalAlignment)
        to.Slot:SetVerticalAlignment(from.Slot.VerticalAlignment)
    end)
end

-- The button writes its default text when it joins the widget tree, so the label is set after adding it.
-- SetWidgetText (the dialogue-choice setter) is what fills the visible label, but it also plays the choice's
-- slide-in animation: call it exactly once (calling it twice made the labels jitter). The delayed pass only
-- touches plain text setters, and only if the label was overwritten.
local function set_label(b, label)
    local t = U.text(label)
    pcall(function() b:SetWidgetText({ ChoiceText = t, ChoiceIndex = 0, Last = false }) end)
    pcall(function() b:UpdateButtonText(t) end)
    pcall(function() b.PBZCommonLocRichText_39:SetText(t) end)
    pcall(function() b.Selected:SetText(t) end)
    U.after(150, function()
        if not U.valid(b) then return end
        local shown = nil
        pcall(function() shown = b.PBZCommonLocRichText_39:GetText():ToString() end)
        if shown ~= label then
            local t2 = U.text(label)
            pcall(function() b:UpdateButtonText(t2) end)
            pcall(function() b.PBZCommonLocRichText_39:SetText(t2) end)
            pcall(function() b.Selected:SetText(t2) end)
        end
    end)
end

-- Gamepad navigation. The bell menu's buttons have explicit Up/Down links set in the designer, so a button
-- slipped in between is skipped; we relink explicitly. EUINavigation: Up = 2, Down = 3.
local UP, DOWN = 2, 3

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

-- The focusable button inside a slot widget (the slot may be a wrapper such as a border).
local function focus_target(w, depth)
    depth = depth or 0
    if not U.valid(w) or depth > 4 then return nil end
    if is_button(w) then return w end
    local found = nil
    pcall(function()
        for i = 0, w:GetChildrenCount() - 1 do
            found = found or focus_target(w:GetChildAt(i), depth + 1)
        end
    end)
    return found
end

local function link(a, b)
    if not (U.valid(a) and U.valid(b)) then return end
    pcall(function() a:SetNavigationRuleExplicit(DOWN, b) end)
    pcall(function() b:SetNavigationRuleExplicit(UP, a) end)
end

-- Chain a list of buttons top to bottom, wrapping around.
local function chain(list)
    for i = 1, #list do link(list[i], list[i % #list + 1]) end
end

local function find_group(menu)
    for _, g in ipairs(FindAllOf("CommonButtonGroupBase") or {}) do
        local ok, idx = pcall(function() return g:FindButtonIndex(menu.TeleportBtn) end)
        if ok and idx and idx >= 0 then return g end
    end
    return nil
end

local function new_button(label, fn)
    local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local b = wbl:Create(cur.menu, cur.menu.TeleportBtn:GetClass(), UEHelpers.GetPlayerController())
    handlers[b:GetFullName()] = fn
    return b
end

local function add(b, label)
    cur.box:AddChildToVerticalBox(b)
    slot_copy(cur.anchor, b)
    set_label(b, label)
    pcall(function() if cur.group then cur.group:AddWidget(b) end end)
    pcall(function() b:DoSelectedAppearance(false) end)
end

local function clear_added()
    for _, w in ipairs(cur.added) do
        pcall(function() if cur.group then cur.group:RemoveWidget(w) end end)
        pcall(function() cur.box:RemoveChild(w) end)
        handlers[w:GetFullName()] = nil
    end
    cur.added = {}
end

-- Show a page: items = { { label, fn }, ... }; focus = index of the row to focus (default 1).
-- Hides the menu's own options while a page is up.
function M.show(items, focus)
    if not cur then return end
    if #cur.hidden == 0 then
        for _, w in ipairs(children(cur.box)) do
            if w:IsVisible() then cur.hidden[#cur.hidden + 1] = { w = w, vis = w:GetVisibility() } w:SetVisibility(1) end
        end
    end
    clear_added()
    for _, it in ipairs(items) do
        local b = new_button(it[1], it[2])
        add(b, it[1])
        cur.added[#cur.added + 1] = b
    end
    chain(cur.added)
    U.after(50, function() pcall(function() cur.added[focus or 1]:SetFocus() end) end)
end

-- Back to the bell menu's own options.
function M.restore()
    if not cur then return end
    clear_added()
    for _, h in ipairs(cur.hidden) do pcall(function() h.w:SetVisibility(h.vis) end) end
    cur.hidden = {}
    pcall(function() cur.entry:SetFocus() end)
end

function M.close()
    if cur and U.valid(cur.menu) then pcall(function() cur.menu:ClickCloseButton() end) end
end

function M.current_menu() return cur and cur.menu end

-- Shared with other menus (the pause menu): route clicks on button b to fn, and label a game button.
function M.bind(b, fn) handlers[b:GetFullName()] = fn end
function M.unbind(b) pcall(function() handlers[b:GetFullName()] = nil end) end
M.set_label = set_label

local function inject(menu, on_entry)
    local anchor = menu.TeleportBtn
    local box = anchor:GetParent()
    local guard = 0
    while U.valid(box) and box:GetClass():GetFName():ToString() ~= "VerticalBox" and guard < 8 do
        anchor, box, guard = box, box:GetParent(), guard + 1
    end
    if not U.valid(box) then U.log("menu: no VerticalBox above TeleportBtn") return end
    cur = { menu = menu, box = box, anchor = anchor, group = find_group(menu), hidden = {}, added = {} }
    -- UMG has no InsertChildAt: take out what follows the anchor, add ours, put them back.
    local after, seen = {}, false
    for _, w in ipairs(children(box)) do
        if seen then after[#after + 1] = { w = w, pad = w.Slot.Padding, h = w.Slot.HorizontalAlignment, v = w.Slot.VerticalAlignment } end
        if w:GetFullName() == anchor:GetFullName() then seen = true end
    end
    for _, a in ipairs(after) do box:RemoveChild(a.w) end
    local entry = new_button(nil, on_entry)
    add(entry, require("i18n").t("entry"))
    cur.entry = entry
    for _, a in ipairs(after) do
        box:AddChildToVerticalBox(a.w)
        pcall(function() a.w.Slot:SetPadding(a.pad) a.w.Slot:SetHorizontalAlignment(a.h) a.w.Slot:SetVerticalAlignment(a.v) end)
    end
    -- Joining the group made our entry the selected one; the menu opens on 穿行 in the original game.
    U.after(120, function()
        pcall(function()
            if cur and cur.group then cur.group:SelectButtonAtIndex(cur.group:FindButtonIndex(menu.TeleportBtn), false) end
        end)
        pcall(function() menu.TeleportBtn:SetFocus() end)
    end)
    -- Re-added options rebuild their Slate widgets and come back with a stale text size until they are
    -- selected once: refresh their style and unselected look now.
    U.after(100, function()
        for _, a in ipairs(after) do
            local t = focus_target(a.w)
            if t and t ~= entry then
                pcall(function() t:UpdateButtonStyle() end)
                pcall(function() t:DoSelectedAppearance(false) end)
            end
        end
    end)
    -- Gamepad: 穿行 -> 强敌挑战 -> the next visible option.
    local above = focus_target(anchor)
    local below = nil
    for _, a in ipairs(after) do
        if a.w:IsVisible() then below = focus_target(a.w) if below then break end end
    end
    -- Relink the whole visible column top to bottom, wrapping (last <-> first).
    local col = {}
    for _, w in ipairs(children(box)) do
        if w:IsVisible() then
            local t = focus_target(w)
            if t then col[#col + 1] = t end
        end
    end
    chain(col)
    U.log("menu: nav chain of %d (%s -> entry -> %s)", #col, above and above:GetFName():ToString() or "?", below and below:GetFName():ToString() or "?")
    U.log("menu: entry added after %s (group %s)", anchor:GetFName():ToString(), cur.group and "joined" or "not found")
end

-- on_entry() is called when 「强敌挑战」 is chosen. enabled() decides whether the entry is added at all.
function M.install(on_entry, enabled)
    NotifyOnNewObject("/Game/PBZContent/UI/InGame/Bell/W_BellMenu.W_BellMenu_C", function(menu)
        cur = nil
        U.after(400, function()
            if not U.valid(menu) or not U.valid(menu.TeleportBtn) then return end
            if enabled and not enabled() then return end
            local ok, err = pcall(inject, menu, on_entry)
            if not ok then U.log("menu inject failed: %s", tostring(err)) end
        end)
    end)
    local last = 0
    local function on_click(self)
        local ok, b = pcall(function() return self:get() end)
        if not ok or not U.valid(b) then return end
        local fn = handlers[b:GetFullName()]
        if not fn then return end
        local now = os.clock()
        if now - last < 0.2 then return end
        last = now
        ExecuteInGameThread(function()
            local ok2, err = pcall(fn)
            if not ok2 then U.log("menu handler error: %s", tostring(err)) end
        end)
    end
    for _, f in ipairs({ "/Script/CommonUI.CommonButtonBase:HandleButtonClicked", "/Script/CommonUI.CommonButtonBase:BP_OnClicked" }) do
        pcall(RegisterHook, f, on_click)
    end
end

return M
