-- Bell menu: adds 「强敌挑战」 below 穿行, and shows our pages in place of the menu's own options, using the
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

local function add_button(L, label, fn)
    local b = W.new_button(L.menu, L.menu.TeleportBtn)
    W.on_click(b, OWNER, fn)
    return b
end

local function join(L, b, label)
    W.set_label(b, label)
    pcall(function() if L.group then L.group:AddWidget(b) end end)
    pcall(function() b:DoSelectedAppearance(false) end)
end

local function focus_later(b)
    local r = U.ref(b)
    U.after(50, function()
        local o = U.get(r)
        if o then o:SetFocus() end
    end)
end

-- The back key on our pages. The menu's back key closes the whole bell menu (W_BellMenu handles it in
-- HandleOverrideBackInputAction). While our pages are up the game's binding is taken off with the menu's own
-- ClearBackKey() and put back with BindBackKey() (UPBZActivatableWidget), and the keys are read here instead:
-- a press goes one page up (user request).
local BACK_KEYS = { "Escape", "Gamepad_FaceButton_Right" }
local BACK_MS = 50

local function watch_back(menu_ref)
    local was_down = true            -- a key still held when the page opened is not a press
    U.every(BACK_MS, function()
        local L = cur and cur.menu == menu_ref and cur.back_taken and live()
        if not L then return true end
        local down = U.any_key_down(BACK_KEYS)
        if down and not was_down and cur.on_back then
            U.log("menu: back key, one page up")
            cur.on_back()
        end
        was_down = down
        return false
    end)
end

local function take_back(L)
    if cur.back_taken then return end
    local ok, err = pcall(function() L.menu:ClearBackKey() end)
    if not ok then U.log("menu: ClearBackKey failed: %s", tostring(err)) return end
    cur.back_taken = true
    watch_back(cur.menu)
end

local function give_back(L)
    if not cur.back_taken then return end
    cur.back_taken, cur.on_back = false, nil
    local ok, err = pcall(function() L.menu:BindBackKey() end)
    if not ok then U.log("menu: BindBackKey failed: %s", tostring(err)) end
end

-- Show a page: items = { { label, fn }, ... }; focus = index of the row to focus (default 1); on_back = what the
-- back key does (one page up). The menu's own options are hidden while a page is up.
function M.show(items, focus, on_back)
    local L = live()
    if not L then return end
    cur.on_back = on_back
    take_back(L)
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
        local b = add_button(L, it[1], it[2])
        W.append(L.box, b, L.like)
        join(L, b, it[1])
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

-- Hand selection back to the first other visible option if joining the group made our entry the selected
-- button: the menu's script would otherwise turn every confirm press into 穿行. Never touches a selection
-- the player made.
local function return_selection(first_ref)
    local L = live()
    local first = U.get(first_ref)
    if not (L and L.group and L.entry and first) then return end
    local sel_is_entry = false
    pcall(function() sel_is_entry = L.group:GetSelectedButtonBase():GetFullName() == L.entry:GetFullName() end)
    if not sel_is_entry then return end
    pcall(function() L.group:SelectButtonAtIndex(L.group:FindButtonIndex(first), false) end)
    pcall(function() first:SetFocus() end)
    pcall(function() L.entry:DoSelectedAppearance(false) end)
    U.log("menu: selection handed back to %s", first:GetFName():ToString())
end

-- Re-added options rebuild their Slate widgets and come back with a stale text size until they are
-- selected once: refresh their style and unselected look.
local function refresh_style(moved_refs)
    local L = live()
    if not (L and L.entry) then return end
    for _, w in ipairs(gets(moved_refs)) do
        local t = W.focus_target(w)
        if t and t:GetFullName() ~= L.entry:GetFullName() then
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
    -- 强敌挑战 goes right below 穿行 (user decision).
    local entry = add_button(L, nil, on_entry)
    local moved = W.insert(box, like, entry, like)
    join(L, entry, i18n.t("entry"))
    cur.entry = U.ref(entry)
    local col = W.visible_buttons(box)
    W.chain(col)
    local first = nil
    for _, t in ipairs(col) do
        if t:GetFullName() ~= entry:GetFullName() then first = t break end
    end
    local moved_refs = {}
    for _, w in ipairs(moved) do moved_refs[#moved_refs + 1] = U.ref(w) end
    local first_ref = U.ref(first)
    U.after(100, function() refresh_style(moved_refs) end)
    U.after(150, function() return_selection(first_ref) end)
    U.log("menu: entry added below %s, %d options linked (group %s, text %s)", like:GetFName():ToString(), #col,
        group and "joined" or "not found", i18n.zh() and "zh" or "en")
    return true
end

-- Keep the column's gamepad links right while this menu lives; ends when the menu is gone or replaced.
local function keep_linked(menu_ref)
    U.every(RELINK_MS, function()
        local L = cur and cur.menu == menu_ref and live()
        if not L then
            U.log("menu: closed, relink loop ended")
            return true
        end
        if L.menu:IsVisible() then relink(L.box) end
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

-- on_entry() is called when 「强敌挑战」 is chosen. enabled() decides whether the entry is added at all.
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
