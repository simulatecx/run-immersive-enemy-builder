-- ESC -> Options -> AddOns -> RUN: the Blizzard settings panel, mirroring the
-- Ledger's checkboxes from the same Settings.defs list. The modern Settings
-- API has shifted across client versions, so the WHOLE registration is one
-- pcall - if the shape differs on Forever, we lose nothing: the Account
-- Ledger (minimap button) remains the canonical options surface.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Options = {}
RUN.Options = Options

if not _G.CreateFrame then return Options end

local registered = false

local function register()
    if registered then return end
    local S = _G.Settings
    if not (S and S.RegisterVerticalLayoutCategory and S.RegisterProxySetting
            and S.CreateCheckbox and S.RegisterAddOnCategory) then
        return
    end
    local ok = pcall(function()
        local category = S.RegisterVerticalLayoutCategory("RUN")
        for _, def in ipairs(RUN.Settings.defs) do
            local setting = S.RegisterProxySetting(
                category, "RUN_" .. def.key, S.VarType.Boolean, def.label,
                RUN.Settings.defaults[def.key],
                function() return RUN.Settings.get(def.key) end,
                function(v)
                    RUN.Settings.set(def.key, v and true or false)
                    if def.key == "expansiveStats" and RUN.Panel then RUN.Panel.refresh() end
                    if def.key == "minimapButton" and RUN.MinimapButton then RUN.MinimapButton.refresh() end
                end)
            S.CreateCheckbox(category, setting)
        end
        S.RegisterAddOnCategory(category)
    end)
    registered = ok and true or false
    Options.registered = registered   -- surfaced by /ra diag
end

RUN.on("PLAYER_LOGIN", register)

return Options
