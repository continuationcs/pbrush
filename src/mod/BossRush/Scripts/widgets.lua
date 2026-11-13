-- Helpers for working inside the game's own menus (bell menu, in-game menu): find a menu's button column,
-- insert a button into it without disturbing the other options' layout, label a game button, and wire
-- gamepad navigation. One click hook for every button we add.
local U = require("util")
local UEHelpers = require("UEHelpers")

local W = {}

-- EUINavigation
local UP, DOWN = 2, 3

function W.children(box)
    local out = {}
    for i = 0, box:GetChildrenCount() - 1 do out[#out + 1] = box:GetChildAt(i) end
    return out
end

-- Whether o's class is, or derives from, the class with this short name.
function W.is_a(o, class_name)
    local ok, r = pcall(function()
        local c = o:GetClass()
        while U.valid(c) do
            if c:GetFName():ToString() == class_name then return true end
            c = c:GetSuperStruct()
        end
        return false
    end)
    return ok and r
end

function W.is_button(o) return W.is_a(o, "CommonButtonBase") end

-- Close the screen a widget is on: the outermost CommonActivatableWidget among its owners (a widget's outer is
-- its WidgetTree, whose outer is the user widget holding it), deactivated as CommonUI's own back action does.
function W.close_screen(widget)
    local top, o, guard = nil, widget, 0
    while o ~= nil and guard < 24 do
        if W.is_a(o, "CommonActivatableWidget") then top = o end
        local ok, outer = pcall(function() return o:GetOuter() end)
        o = (ok and U.valid(outer)) and outer or nil
        guard = guard + 1
    end
    if not top then return nil end
    pcall(function() top:DeactivateWidget() end)
    return top:GetFName():ToString()
end

-- The focusable button inside a column entry (the entry may be a wrapper such as a border).
function W.focus_target(w, depth)
    depth = depth or 0
    if not U.valid(w) or depth > 4 then return nil end
    if W.is_button(w) then return w end
    local found = nil
    pcall(function()
        for i = 0, w:GetChildrenCount() - 1 do
            found = found or W.focus_target(w:GetChildAt(i), depth + 1)
        end
    end)
    return found
end

-- The VerticalBox holding `widget`, and the direct child of it that contains `widget` (its column entry).
function W.column_of(widget)
    local entry, box, guard = widget, widget:GetParent(), 0
    while U.valid(box) and box:GetClass():GetFName():ToString() ~= "VerticalBox" and guard < 8 do
        entry, box, guard = box, box:GetParent(), guard + 1
    end
    if not U.valid(box) then return nil end
    return box, entry
end

local function slot_of(w)
    return { pad = w.Slot.Padding, h = w.Slot.HorizontalAlignment, v = w.Slot.VerticalAlignment }
end

local function apply_slot(w, s)
    pcall(function()
        w.Slot:SetPadding(s.pad)
        w.Slot:SetHorizontalAlignment(s.h)
        w.Slot:SetVerticalAlignment(s.v)
    end)
end

-- Insert `new` into `box` right after the child `after` (nil = at the top), laid out like `like`.
-- UMG has no InsertChildAt: the children that follow are taken out and put back with their slot settings.
-- Returns the children that were moved (they may need a style refresh).
function W.insert(box, after, new, like)
    local moved, seen = {}, after == nil
    for _, c in ipairs(W.children(box)) do
        if seen then moved[#moved + 1] = { w = c, slot = slot_of(c) } end
        if not seen and c:GetFullName() == after:GetFullName() then seen = true end
    end
    for _, m in ipairs(moved) do box:RemoveChild(m.w) end
    box:AddChildToVerticalBox(new)
    apply_slot(new, slot_of(like))
    for _, m in ipairs(moved) do
        box:AddChildToVerticalBox(m.w)
        apply_slot(m.w, m.slot)
    end
    local out = {}
    for _, m in ipairs(moved) do out[#out + 1] = m.w end
    return out
end

-- Append `new` at the end of `box`, laid out like `like`.
function W.append(box, new, like)
    box:AddChildToVerticalBox(new)
    apply_slot(new, slot_of(like))
end

-- A new button of the same class as `template`, owned by `outer`.
function W.new_button(outer, template)
    local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    return wbl:Create(outer, template:GetClass(), UEHelpers.GetPlayerController())
end

-- Label a game button, after it has been added (it writes its default text when it joins the widget tree).
-- The bell menu's dialogue buttons fill their visible label through SetWidgetText, which also plays their
-- slide-in animation: it is called exactly once (twice made labels jitter). The plain setters cover other
-- classes; the delayed pass uses only those, and only if the label was overwritten meanwhile.
local function plain_label(b, t)
    pcall(function() b:UpdateButtonText(t) end)
    pcall(function() b.PBZCommonLocRichText_39:SetText(t) end)
    pcall(function() b.Selected:SetText(t) end)
end

function W.set_label(b, label)
    pcall(function() b:SetWidgetText({ ChoiceText = U.text(label), ChoiceIndex = 0, Last = false }) end)
    plain_label(b, U.text(label))
    local r = U.ref(b)
    U.after(150, function()
        local b = U.get(r)
        if not b then return end
        local shown = nil
        pcall(function() shown = b.PBZCommonLocRichText_39:GetText():ToString() end)
        if shown and shown ~= label then plain_label(b, U.text(label)) end
    end)
end

-- Explicit gamepad links: a -> b going down, b -> a going up.
function W.link(a, b)
    if not (U.valid(a) and U.valid(b)) then return end
    pcall(function() a:SetNavigationRuleExplicit(DOWN, b) end)
    pcall(function() b:SetNavigationRuleExplicit(UP, a) end)
end

-- Link a list of buttons top to bottom, wrapping around.
function W.chain(list)
    for i = 1, #list do W.link(list[i], list[i % #list + 1]) end
end

-- The visible buttons of a column, top to bottom.
function W.visible_buttons(box)
    local out = {}
    for _, c in ipairs(W.children(box)) do
        if c:IsVisible() then
            local t = W.focus_target(c)
            if t then out[#out + 1] = t end
        end
    end
    return out
end

-- Clicks on the buttons we add. One hook on CommonButtonBase's native click handler (bound to the Slate
-- button's click delegate, so mouse, Enter and the gamepad confirm all pass through it), routed by button.
-- Handlers are grouped by owner so a menu can drop all of its old ones when it is rebuilt: object names can
-- be reused after garbage collection, and a stale entry would catch clicks on some other game button.
local handlers = {}      -- button full name -> { fn, owner }

function W.on_click(b, owner, fn) handlers[b:GetFullName()] = { fn = fn, owner = owner } end
function W.forget(b) pcall(function() handlers[b:GetFullName()] = nil end) end
function W.forget_owner(owner)
    for k, h in pairs(handlers) do if h.owner == owner then handlers[k] = nil end end
end

-- The handler runs after the click has been handled (U.after 0): it may rebuild the very column it came from.
U.hook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", function(self)
    local ok, b = pcall(function() return self:get() end)
    if not ok or not U.valid(b) then return end
    local h = handlers[b:GetFullName()]
    if h then U.after(0, h.fn) end
end)

return W
