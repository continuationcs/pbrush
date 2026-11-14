-- Bell menu: adds 「残影试炼」 below 穿行, and shows our pages in place of the menu's own options, using the
-- menu's own button class and button group, so look, sound and gamepad navigation are native.
--
-- No Blueprint function of the menu is hooked (hooks on Blueprint functions crashed the game). The entry is
-- inserted as soon as the new menu's buttons exist, before it is on screen; afterwards a light loop keeps the
-- column's gamepad links right, because the menu's script rewrites its navigation whenever it activates
-- (on opening, and on coming back from 穿行, 能力修行 ...).
-- Every widget kept between calls is a weak ref (U.ref / U.get): the menu is freed some time after it closes.
local U = require("util")
local W = require("widgets")
local i18n = require("i18n")

local M = {}

local MENU_CLASS = "/Game/PBZContent/UI/InGame/Bell/W_BellMenu.W_BellMenu_C"
local OWNER = "bell"
local RELINK_MS = 250

-- The current menu, all refs: { menu, box, like, group, entry, hidden = {{ref, vis}}, added = {refs} }.
local cur = nil

local function find_group(menu)
    for _, g in ipairs(U.find_all("CommonButtonGroupBase")) do
        local ok, idx = pcall(function() return g:FindButtonIndex(menu.TeleportBtn) end)
        if ok and idx and idx >= 0 then return g end
    end
    return nil
end

-- The current menu's live objects, or nil when the menu is gone.
local function live()
    if not cur then return nil end
    local menu, box, like = U.get(cur.menu), U.get(cur.box), U.get(cur.like)
    if not (menu and box and like) then return nil end
    return { menu = menu, box = box, like = like, group = U.get(cur.group), entry = U.get(cur.entry) }
end

local function gets(refs)
    local out = {}
    for _, r in ipairs(refs) do
        local o = U.get(r)
        if o then out[#out + 1] = o end
    end
    return out
end

-- Gamepad links for whatever the column shows now (the menu's options, or one of our pages), top to bottom,
-- wrapping. Touches no selection, focus or style.
local function relink(box)
    W.chain(W.visible_buttons(box))
end

local function clear_added(L)
    for _, b in ipairs(gets(cur.added)) do
        pcall(function() if L.group then L.group:RemoveWidget(b) end end)
        pcall(function() L.box:RemoveChild(b) end)
        W.forget(b)
    end
    cur.added = {}
end

-- Label a new button, join the menu's button group (selected look, and clicks: see widgets.lua) and route
-- its clicks to fn.
local function join(L, b, label, fn)
    W.set_label(b, label)
    local grouped = false
    if L.group then
        local ok, err = pcall(function() L.group:AddWidget(b) end)
        grouped = ok
        if not ok then U.log("menu: joining the button group failed: %s", tostring(err)) end
    end
    pcall(function() b:DoSelectedAppearance(false) end)
    W.on_click(b, OWNER, fn, grouped)
end

local function focus_later(b)
    local r = U.ref(b)
    U.after(50, function()
        local o = U.get(r)
        if o then o:SetFocus() end
    end)
end

-- The back key on our pages goes one page up (user request) instead of closing the bell menu (W_BellMenu
-- handles its back key in HandleOverrideBackInputAction). While our pages are up the menu's binding is taken off
-- with its own ClearBackKey() and put back with BindBackKey() (UPBZActivatableWidget), and each page's 返回 row
-- is given the back input action as its triggering action (CommonUI), so the key clicks that row. Reading the
-- keys ourselves does not work here: with the menu open the game is in UI-only input and
-- PlayerController:IsInputKeyDown sees nothing. The triggered click reaches us through the button group's
-- click handler (widgets.lua).
local function back_action(menu)
    local found = nil
    pcall(function()
        local a = menu.CloseBtn.TriggeringEnhancedInputAction
        if U.valid(a) then found = { enhanced = a, from = "CloseBtn enhanced " .. a:GetFName():ToString() } end
    end)
    for _, src in ipairs({ { menu.CloseBtn, "TriggeringInputAction" }, { menu, "OverrideBackInputActionData_Game" },
                           { menu, "OverrideBackInputActionData_Editor" } }) do
        if found then break end
        pcall(function()
            local r = src[1][src[2]]
            local row = r.RowName:ToString()
            if row ~= "None" then found = { row = { DataTable = r.DataTable, RowName = r.RowName }, from = src[2] .. " " .. row } end
        end)
    end
    if not cur.back_logged then
        cur.back_logged = true
        U.log("menu: back action %s", found and found.from or "not found")
    end
    return found
end

local function bind_back(b, action)
    if not action then return end
    local ok, err = pcall(function()
        if action.enhanced then b:SetTriggeringEnhancedInputAction(action.enhanced)
        else b:SetTriggeringInputAction(action.row) end
    end)
    if not ok then U.log("menu: back action not set: %s", tostring(err)) end
end

local function take_back(L)
    if cur.back_taken then return end
    local ok, err = pcall(function() L.menu:ClearBackKey() end)
    if not ok then U.log("menu: ClearBackKey failed: %s", tostring(err)) return end
    cur.back_taken = true
end

local function give_back(L)
    if not cur.back_taken then return end
    cur.back_taken = false
    local ok, err = pcall(function() L.menu:BindBackKey() end)
    if not ok then U.log("menu: BindBackKey failed: %s", tostring(err)) end
end

-- Show a page: items = { { label, fn, back = true? }, ... }: the back key clicks the row marked back (one page
-- up); focus = index of the row to focus (default 1). The menu's own options are hidden while a page is up.
function M.show(items, focus)
    local L = live()
    if not L then return end
    take_back(L)
    local action = back_action(L.menu)
    if #cur.hidden == 0 then
        for _, w in ipairs(W.children(L.box)) do
            if w:IsVisible() then
                cur.hidden[#cur.hidden + 1] = { ref = U.ref(w), vis = w:GetVisibility() }
                w:SetVisibility(1)     -- Collapsed
            end
        end
    end
    clear_added(L)
    local added = {}
    for _, it in ipairs(items) do
        local b = W.new_button(L.menu, L.menu.TeleportBtn)
        W.append(L.box, b, L.like)
        join(L, b, it[1], it[2])
        if it.back then bind_back(b, action) end
        added[#added + 1] = b
        cur.added[#cur.added + 1] = U.ref(b)
    end
    W.chain(added)
    if added[focus or 1] then focus_later(added[focus or 1]) end
end

-- Back to the bell menu's own options.
function M.restore()
    local L = live()
    if not L then return end
    clear_added(L)
    for _, h in ipairs(cur.hidden) do
        local w = U.get(h.ref)
        if w then pcall(function() w:SetVisibility(h.vis) end) end
    end
    cur.hidden = {}
    give_back(L)
    relink(L.box)
    if L.entry then pcall(function() L.entry:SetFocus() end) end
end

function M.close()
    local L = live()
    if L then pcall(function() L.menu:ClickCloseButton() end) end
end

-- Full name of the group's selected button, or nil. Right after the menu reactivates no button is selected and
-- GetSelectedButtonBase() returns a null object: calling anything on it but IsValid crashed the game natively
-- (null + 0x18, the object's name, 2026-11-14), so it is checked with U.valid before use.
local function selected_name(group)
    local name = nil
    pcall(function()
        local b = group:GetSelectedButtonBase()
        if U.valid(b) then name = b:GetFullName() end
    end)
    return name
end

-- Hand selection back to the first other visible option if joining the group made our entry the selected
-- button: the menu's script would otherwise turn every confirm press into 穿行. Never touches a selection
-- the player made.
local function return_selection(first_ref)
    local L = live()
    local first = U.get(first_ref)
    if not (L and L.group and L.entry and first) then return end
    if selected_name(L.group) ~= L.entry:GetFullName() then return end
    pcall(function() L.group:SelectButtonAtIndex(L.group:FindButtonIndex(first), false) end)
    pcall(function() first:SetFocus() end)
    pcall(function() L.entry:DoSelectedAppearance(false) end)
    U.log("menu: selection handed back to %s", first:GetFName():ToString())
end

-- Buttons whose Slate widgets were rebuilt outside the menu's script come back with a stale text style (larger,
-- bold) until they are selected once: options re-added by the insertion, and our entry whenever the menu comes
-- back from one of its sub-screens (能力修行 ...), where the script restyles only its own buttons. Refresh their
-- style and, unless selected, their unselected look.
local function refresh_style(refs)
    for _, w in ipairs(gets(refs)) do
        local t = W.focus_target(w)
        if t then
            pcall(function() t:UpdateButtonStyle() end)
            local selected = false
            pcall(function() selected = t:GetSelected() end)
            if not selected then pcall(function() t:DoSelectedAppearance(false) end) end
        end
    end
end

local function inject(menu, on_entry)
    local box, like = W.column_of(menu.TeleportBtn)
    if not box then U.log("menu: no VerticalBox above TeleportBtn") return false end
    local group = find_group(menu)
    cur = { menu = U.ref(menu), box = U.ref(box), like = U.ref(like), group = U.ref(group), hidden = {}, added = {} }
    local L = { menu = menu, box = box, like = like, group = group }
    -- 残影试炼 goes right below 穿行 (user decision).
    local entry = W.new_button(menu, menu.TeleportBtn)
    local moved = W.insert(box, like, entry, like)
    join(L, entry, i18n.t("entry"), on_entry)
    cur.entry = U.ref(entry)
    local col = W.visible_buttons(box)
    W.chain(col)
    local first = nil
    for _, t in ipairs(col) do
        if t:GetFullName() ~= entry:GetFullName() then first = t break end
    end
    local moved_refs = {}
    for _, w in ipairs(moved) do moved_refs[#moved_refs + 1] = U.ref(w) end
    cur.moved = moved_refs
    local first_ref = U.ref(first)
    U.after(100, function() refresh_style(moved_refs) end)
    U.after(150, function() return_selection(first_ref) end)
    U.log("menu: entry added below %s, %d options linked (group %s, text %s)", like:GetFName():ToString(), #col,
        group and "joined" or "not found", i18n.zh() and "zh" or "en")
    return true
end

-- What the entry looks like now, for the log: selected, which button the group has selected, focus.
local function entry_state(L)
    local sel, focus = "?", "?"
    local group_sel = L.group and selected_name(L.group) or nil
    group_sel = group_sel and group_sel:match("([^%.:]+)$") or "none"
    pcall(function() sel = tostring(L.entry:GetSelected()) end)
    pcall(function() focus = tostring(L.entry:HasKeyboardFocus()) end)
    return string.format("selected %s, group selected %s, focus %s", sel, group_sel, focus)
end

local function index_in(group, b)
    local idx = -1
    pcall(function() idx = group:FindButtonIndex(b) end)
    return idx
end

-- When the menu comes back from a sub-screen its button group has no selection and our entry reports itself
-- selected without the group knowing it (log, 2026-11-14): the entry has dropped out of the group, so moving
-- the cursor off it no longer deselects it (it stayed bold) and its clicks, routed through the group, are lost.
-- Put it back in the menu's group (found again through 穿行, in case the script made a new one), leaving the
-- group's selection as the game had it.
local function rejoin(L)
    local g = find_group(L.menu)
    if not g then U.log("menu: rejoin: no group holds 穿行") return nil end
    local same = L.group ~= nil and g:GetFullName() == L.group:GetFullName()
    local count = -1
    pcall(function() count = g:GetButtonCount() end)
    local idx = index_in(g, L.entry)
    U.log("menu: rejoin: group %s, %d buttons, entry index %d", same and "same" or "new", count, idx)
    cur.group = U.ref(g)
    if idx >= 0 then return g end
    local before = selected_name(g)
    local ok, err = pcall(function() g:AddWidget(L.entry) end)
    if not ok then U.log("menu: rejoin failed: %s", tostring(err)) return g end
    -- Joining selects the newcomer when nothing is selected, and the menu's script then turns confirm into 穿行.
    if before == nil and selected_name(g) == L.entry:GetFullName() then pcall(function() g:DeselectAll() end) end
    -- A selection the entry kept while outside the group (cursor passed over it) that the group does not share
    -- and the player is not on: clear it, or it stays bold.
    local sel, focus = false, false
    pcall(function() sel = L.entry:GetSelected() == true end)
    pcall(function() focus = L.entry:HasKeyboardFocus() == true end)
    if sel and not focus and selected_name(g) ~= L.entry:GetFullName() then
        pcall(function() L.entry:SetIsSelected(false, false) end)
    end
    U.log("menu: rejoin: entry index now %d, group selected %s", index_in(g, L.entry), tostring(selected_name(g)))
    return g
end

-- Keep the column's gamepad links right while this menu lives, and put our entry back in the button group and
-- restyle it (and the options the insertion moved) each time the menu comes back from a sub-screen; ends when
-- the menu is gone or replaced.
local function keep_linked(menu_ref)
    local was_up = true
    U.every(RELINK_MS, function()
        local L = cur and cur.menu == menu_ref and live()
        if not L then
            U.log("menu: closed, relink loop ended")
            return true
        end
        local visible, active = L.menu:IsVisible(), false
        pcall(function() active = L.menu:IsActivated() == true end)
        local up = visible and active
        if up ~= was_up then
            U.log("menu: %s (visible %s, activated %s)", up and "back" or "left", tostring(visible), tostring(active))
            if up and L.entry then
                U.log("menu: entry before restyle: %s", entry_state(L))
                L.group = rejoin(L) or L.group
                local refs = { cur.entry }
                for _, r in ipairs(cur.moved or {}) do refs[#refs + 1] = r end
                refresh_style(refs)
                U.log("menu: entry after restyle: %s", entry_state(L))
            end
            was_up = up
        end
        if visible then relink(L.box) end
    end)
end

-- When the mod turns itself off with a menu open: take our entry and pages out and leave the menu as the game
-- made it, its gamepad links and selection included.
local function remove_all()
    local L = live()
    if L then
        clear_added(L)
        for _, h in ipairs(cur.hidden) do
            local w = U.get(h.ref)
            if w then pcall(function() w:SetVisibility(h.vis) end) end
        end
        if L.entry then
            pcall(function() if L.group then L.group:RemoveWidget(L.entry) end end)
            pcall(function() L.box:RemoveChild(L.entry) end)
        end
        give_back(L)
        local col = W.visible_buttons(L.box)
        W.chain(col)
        if col[1] then
            pcall(function() if L.group then L.group:SelectButtonAtIndex(L.group:FindButtonIndex(col[1]), false) end end)
            pcall(function() col[1]:SetFocus() end)
        end
    end
    cur = nil
    W.forget_owner(OWNER)
end

-- on_entry() is called when 「残影试炼」 is chosen. enabled() decides whether the entry is added at all.
function M.install(on_entry, enabled)
    U.on_fail(remove_all)
    U.on_new(MENU_CLASS, function(new_menu)
        -- The object is brand new: its widget tree is built right after. Look every 30 ms (up to 3 s) and insert
        -- the moment 穿行 is there, which is before the menu is drawn and before the player can move.
        local menu_ref = U.ref(new_menu)
        if not menu_ref then return end
        local tries = 0
        U.every(30, function()
            tries = tries + 1
            if tries > 100 or U.failed() then return true end
            local menu = U.get(menu_ref)
            if not menu then return true end
            local ok, ready = pcall(function() return U.valid(menu.TeleportBtn) and U.valid(menu.TeleportBtn:GetParent()) end)
            if not (ok and ready) then return false end
            cur = nil
            W.forget_owner(OWNER)        -- handlers of earlier menus
            if enabled and not enabled() then return true end
            if inject(menu, on_entry) then keep_linked(cur.menu) end
            return true
        end)
    end)
end

return M
