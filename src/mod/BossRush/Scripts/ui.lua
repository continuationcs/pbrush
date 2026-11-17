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
        local w = U.create_widget(cls)
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

-- The game's boss-defeat banner (W_BossDead, the 斩 effect), pushed through the game's own entry
-- BP_GameplayHelper "Push BossDeadUI", which the story flow graphs (BPF_*Death) call. Its argument picks the red
-- variant (W_BossDead_Red); the user chose the normal one (2026-11-17, after seeing both). Bosses whose AI config
-- carries AIScript_ShowUIAfterCombat push it themselves on death (roster native_banner). Optional in the start-up
-- check: missing, a fight ends without it.
local HELPER = "/Game/PBZContent/Blueprint/BP_GameplayHelper.BP_GameplayHelper_C"
function M.boss_banner()
    local stage = "class"
    local ok, err = pcall(function()
        local cls = U.load_class(HELPER)
        if not cls then error("helper class not found") end
        stage = "default object"
        local cdo = cls:GetCDO()
        if not U.valid(cdo) then error("no default object") end
        stage = "call"
        cdo["Push BossDeadUI"](cdo, false, UEHelpers.GetWorld())
    end)
    U.log("banner: %s", ok and "pushed" or ("failed at " .. stage .. ": " .. tostring(err)))
    return ok
end

-- Whether a defeat banner is on screen, pushed by the run or by a boss's own AI.
function M.banner_up() return U.screen_up("W_BossDead_C") end

return M
