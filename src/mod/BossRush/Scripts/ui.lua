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

-- The game's boss-defeat banner (W_BossDead, the 斩 effect; red = W_BossDead_Red), pushed through the game's own
-- entry BP_GameplayHelper "Push BossDeadUI", which the story flow graphs (BPF_*Death) call. Bosses whose AI
-- config carries AIScript_ShowUIAfterCombat push it themselves on death (found offline, 2026-11-16).
local HELPER = "/Game/PBZContent/Blueprint/BP_GameplayHelper.BP_GameplayHelper_C"
function M.boss_banner(red)
    local stage = "class"
    local ok, err = pcall(function()
        local cls = U.load_class(HELPER)
        if not cls then error("helper class not found") end
        stage = "default object"
        local cdo = cls:GetCDO()
        if not U.valid(cdo) then error("no default object") end
        stage = "call"
        cdo["Push BossDeadUI"](cdo, red and true or false, UEHelpers.GetWorld())
    end)
    U.log("banner: %s%s", red and "red" or "normal", ok and " pushed" or (" failed at " .. stage .. ": " .. tostring(err)))
    return ok
end

return M
