-- 「收刃离去」 at the top of the in-game menu while a challenge runs: the first press asks for confirmation
-- (the label changes), the second leaves (counts as a defeat). The menu's layout is not in the header dump,
-- so its button column is found at runtime: the column holding its first visible button.
local U = require("util")
local W = require("widgets")
local i18n = require("i18n")

local M = {}

local MENU_CLASS = "/Game/PBZContent/UI/Hud/WB_GameMenuV1.WB_GameMenuV1_C"
local OWNER = "pause"

-- Buttons the menu holds as properties, in declaration order.
local function menu_buttons(w)
    local out = {}
    pcall(function()
        w:GetClass():ForEachProperty(function(p)
            local okv, v = pcall(function() return w[p:GetFName():ToString()] end)
            if okv and type(v) == "userdata" and U.valid(v) and W.is_button(v) then out[#out + 1] = v end
        end)
    end)
    return out
end

local function inject(w, on_abort)
    local box, like, template
    for _, b in ipairs(menu_buttons(w)) do
        if b:IsVisible() then
            box, like = W.column_of(b)
            if box then template = b break end
        end
    end
    if not box then U.log("pause: no button column found") return end
    local mine = W.new_button(w, template)
    W.insert(box, nil, mine, like)
    W.set_label(mine, i18n.t("abort"))
    -- The handler runs on a later click: look both up again then (U.ref).
    local mine_ref, menu_ref = U.ref(mine), U.ref(w)
    local armed = false
    W.on_click(mine, OWNER, function()
        local b, menu = U.get(mine_ref), U.get(menu_ref)
        if not b then return end
        if not armed then
            armed = true
            W.set_label(b, i18n.t("abort_confirm"))
            return
        end
        W.forget(b)
        if menu then pcall(function() menu:DeactivateWidget() end) end
        U.after(200, on_abort)
    end)
    U.log("pause: 收刃离去 added")
end

-- is_active(): a challenge is running. on_abort(): leave it.
function M.install(is_active, on_abort)
    U.on_new(MENU_CLASS, function(new_menu)
        local menu_ref = U.ref(new_menu)
        U.after(300, function()
            W.forget_owner(OWNER)
            local w = U.get(menu_ref)
            if not w or not is_active() or U.failed() then return end
            inject(w, on_abort)
        end)
    end)
end

return M
