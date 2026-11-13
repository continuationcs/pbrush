-- On-screen text using the game's own tip strip (WB_TipsText: ink background, fade in/out, its own font).
local U = require("util")
local UEHelpers = require("UEHelpers")

local M = {}
local CLASS = "/Game/PBZContent/UI/InGame/SwitchUI/WB_TipsText.WB_TipsText_C"
local current = nil      -- ref (U.ref) of the strip on screen

function M.toast(text, seconds)
    local ok, err = pcall(function()
        local old = U.get(current)
        if old then pcall(function() old:RemoveFromParent() end) end
        local cls = U.load_class(CLASS)
        local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local w = wbl:Create(UEHelpers.GetWorld(), cls, UEHelpers.GetPlayerController())
        w:AddToViewport(50)
        w:SetText(U.text(text))
        pcall(function() w:PlayAnimation(w.FadeIn, 0, 1, 0, 1, false) end)
        local r = U.ref(w)
        current = r
        U.after((seconds or 3) * 1000, function()
            local w2 = U.get(r)
            if not w2 then return end
            pcall(function() w2:PlayAnimation(w2.FadeOut, 0, 1, 0, 1, false) end)
            U.after(600, function()
                local w3 = U.get(r)
                if w3 then w3:RemoveFromParent() end
            end)
        end)
    end)
    U.log("toast: %s%s", text, ok and "" or (" (failed: " .. tostring(err) .. ")"))
end

return M
