-- On-screen text using the game's own tip strip (WB_TipsText: ink background, fade in/out, its own font).
local U = require("util")
local UEHelpers = require("UEHelpers")

local M = {}
local CLASS = "/Game/PBZContent/UI/InGame/SwitchUI/WB_TipsText.WB_TipsText_C"
local current = nil

function M.toast(text, seconds)
    local ok, err = pcall(function()
        if U.valid(current) then pcall(function() current:RemoveFromParent() end) end
        local cls = U.load_class(CLASS)
        local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local w = wbl:Create(UEHelpers.GetWorld(), cls, UEHelpers.GetPlayerController())
        w:AddToViewport(50)
        w:SetText(U.text(text))
        pcall(function() w:PlayAnimation(w.FadeIn, 0, 1, 0, 1, false) end)
        current = w
        U.after((seconds or 3) * 1000, function()
            if not U.valid(w) then return end
            pcall(function() w:PlayAnimation(w.FadeOut, 0, 1, 0, 1, false) end)
            U.after(600, function() if U.valid(w) then w:RemoveFromParent() end end)
        end)
    end)
    U.log("toast: %s%s", text, ok and "" or (" (failed: " .. tostring(err) .. ")"))
end

-- Persistent strip at the top of the screen for a 连战: "连战·三面　2 / 3　01:24". Same native widget, no fades.
local hud = nil

function M.hud_show(text)
    local ok, err = pcall(function()
        if U.valid(hud) then hud:SetText(U.text(text)) return end
        local cls = U.load_class(CLASS)
        local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local w = wbl:Create(UEHelpers.GetWorld(), cls, UEHelpers.GetPlayerController())
        w:AddToViewport(40)
        -- Top centre, sized to its content.
        pcall(function()
            w:SetAnchorsInViewport({ Minimum = { X = 0.5, Y = 0.04 }, Maximum = { X = 0.5, Y = 0.04 } })
            w:SetAlignmentInViewport({ X = 0.5, Y = 0 })
        end)
        w:SetText(U.text(text))
        pcall(function() w:PlayAnimation(w.FadeIn, 0, 1, 0, 1, false) end)
        hud = w
    end)
    if not ok then U.log("hud failed: %s", tostring(err)) end
end

function M.hud_hide()
    if U.valid(hud) then pcall(function() hud:RemoveFromParent() end) end
    hud = nil
end

return M
