-- Result screen: the game's own wb_settlement layout (no logic of its own), filled with our numbers.
-- Layout (from an in-game screenshot of the probe's F3 preview):
--   title (CommonTextBlock_64, big, centre)
--   row 1 centre:  [icon] _6 label   _7 value
--   row 2:         [icon] _2 / _3              [icon] _4 / _5
--   row 3:         [icon] _349 / _419          [icon] (unnamed) / _1
--   _8  small grey line,  _70 bottom strip
-- The icons have no texture set (white squares), so they are hidden.
local U = require("util")
local UEHelpers = require("UEHelpers")

local M = {}
local CLASS = "/Game/PBZContent/UI/UINew/HUD/wb_settlement.wb_settlement_C"
local SLOTS = {
    l1 = "CommonRichTextBlock_6",   v1 = "CommonRichTextBlock_7",
    l2 = "CommonRichTextBlock_2",   v2 = "CommonRichTextBlock_3",
    l3 = "CommonRichTextBlock_4",   v3 = "CommonRichTextBlock_5",
    l4 = "CommonRichTextBlock_349", v4 = "CommonRichTextBlock_419",
    l5 = "CommonRichTextBlock",     v5 = "CommonRichTextBlock_1",
    sub = "CommonRichTextBlock_8",  foot = "CommonRichTextBlock_70",
}
local current = nil      -- ref (U.ref) of the result screen on screen

-- Keys that close the screen early: gamepad A / B, keyboard Enter / Space, mouse click.
-- (Not Esc / Start: those also open the game menu.)
local CLOSE_KEYS = { "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right", "Enter", "SpaceBar", "LeftMouseButton" }

local function widget(w, name)
    local v
    pcall(function() v = w[name] end)
    if U.valid(v) then return v end
    pcall(function() v = w:GetWidgetFromName(FName(name)) end)
    return U.valid(v) and v or nil
end

local function set(w, name, text)
    local t = widget(w, name)
    if t then pcall(function() t:SetText(U.text(text or "")) end) end
end

-- d = { title, rows = { {label, value} x5 }, sub, foot }. Closes after `seconds`, or earlier when the player
-- presses a confirm / back key (after a short grace period, and only a fresh press). on_close() runs once.
function M.show(d, seconds, on_close)
    local ok, err = pcall(function()
        local old = U.get(current)
        if old then pcall(function() old:RemoveFromParent() end) end
        local cls = U.load_class(CLASS)
        local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local w = wbl:Create(UEHelpers.GetWorld(), cls, UEHelpers.GetPlayerController())
        w:AddToViewport(60)
        local r = U.ref(w)
        current = r
        set(w, "CommonTextBlock_64", d.title)
        for i = 1, 5 do
            local row = d.rows[i] or { "", "" }
            set(w, SLOTS["l" .. i], row[1])
            set(w, SLOTS["v" .. i], row[2])
        end
        set(w, SLOTS.sub, d.sub)
        set(w, SLOTS.foot, d.foot)
        for _, n in ipairs({ "Image", "Image_1", "Image_2", "Image_3", "Image_385" }) do
            local img = widget(w, n)
            -- Image_385 may be the background art rather than a row icon: keep anything large.
            if img then pcall(function()
                local sz = img.Brush.ImageSize
                if sz.X <= 64 and sz.Y <= 64 then img:SetVisibility(2) end -- Hidden (keeps layout)
            end) end
        end
        pcall(function() w:PlayAnimation(w.show, 0, 1, 0, 1, false) end)
        local closed = false
        local function close(why)
            if closed then return end
            closed = true
            local w2 = U.get(r)
            if w2 then pcall(function() w2:RemoveFromParent() end) end
            if current == r then current = nil end
            U.log("settle: closed (%s)", why)
            if on_close then on_close() end
        end
        U.after((seconds or 8) * 1000, function() close("timeout") end)
        -- Poll the player's input: wait until every key is released (the hit that ended the fight may still
        -- be held), then close on the next press.
        local t0, released = os.clock(), false
        U.every(50, function()
            if closed then return true end
            if os.clock() - t0 < 1.0 then return false end
            local down = U.any_key_down(CLOSE_KEYS)
            if not released then
                released = not down
            elseif down then
                close("key")
                return true
            end
            return false
        end)
    end)
    U.log("settle: %s%s", d.title or "", ok and "" or (" (failed: " .. tostring(err) .. ")"))
    return ok
end

return M
