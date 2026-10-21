-- The passive layer: no commands needed. Mouse over (or target) any enemy and
-- its tooltip gains RUN's flag line - classification (Elite / Rare / Rare Elite /
-- Boss) plus a danger rank earned from kills. With the "Expansive Enemy Stats"
-- option on, your win-chance line appears beneath it. Pure helpers are headless-
-- tested; injection is display-only (AddLine on the tooltip, never a frame write).

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Tooltip = {}
RUN.Tooltip = Tooltip

-- ---------------------------------------------------------------------------
-- Pure: classification -> flag { label, r, g, b } (normal mobs get no flag).
-- Colours follow the game's own grammar: silver dragon = silver, elite = gold,
-- rare elite = tarnished gold, boss = red.
-- ---------------------------------------------------------------------------
local FLAGS = {
    rare      = { label = "Rare (silver dragon)", r = 0.78, g = 0.86, b = 0.95 },
    elite     = { label = "Elite",                r = 1.00, g = 0.84, b = 0.30 },
    rareelite = { label = "Rare Elite",           r = 1.00, g = 0.62, b = 0.20 },
    worldboss = { label = "World Boss",           r = 1.00, g = 0.30, b = 0.30 },
}
function Tooltip.flagFor(classification)
    return FLAGS[classification]
end

-- Pure: compose the flag line text from a flag, a kill rank, your kill count
-- and the live "deaths heard" count (P2P pings from other RUN users).
function Tooltip.flagLine(flag, rank, kills, heard)
    kills = tonumber(kills) or 0
    heard = tonumber(heard) or 0
    local tally
    if kills > 0 and heard > 0 then
        tally = "killed you " .. kills .. "x + " .. heard .. " heard"
    elseif kills > 0 then
        tally = "killed you " .. kills .. "x"
    elseif heard > 0 then
        tally = heard .. " player deaths heard"
    end
    if flag and rank and tally then
        return flag.label .. " - " .. rank.label .. " (" .. tally .. ")"
    elseif flag then
        return flag.label
    elseif rank and tally then
        return rank.label .. " - " .. tally
    end
    return nil
end

-- Everything below wires the client.
if not _G.CreateFrame then return Tooltip end

local function inject(tooltip)
    if tooltip ~= _G.GameTooltip then return end
    if not RUN.Settings.get("flags") then return end

    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not unit then unit = "mouseover" end
    local info = RUN.Detect.unitInfo(unit)
    if not info or info.isPlayer or not info.hostile then return end

    local kills = RUN.Attribution.killsBy(info.npcID)
    local heard = RUN.Deathping.heardBy(info.npcID)
    local rank = RUN.Attribution.rankForKills(kills + heard)
    local flag = Tooltip.flagFor(info.classification)

    local line = Tooltip.flagLine(flag, rank, kills, heard)
    if line then
        local c = rank or flag
        tooltip:AddLine("RUN: " .. line, c.r, c.g, c.b)
    end

    -- Expansive Enemy Stats: your chances vs this enemy, right on the tooltip.
    if RUN.Settings.get("expansiveStats") and not info.dead then
        local v = RUN.Odds.forUnit(unit)
        if v then
            local r, g, b = RUN.Odds.bandColor(v.band)
            local pctText = v.skull and "no chance"
                or (math.floor(v.p * 100 + 0.5) .. "% to win")
            tooltip:AddLine("RUN: " .. v.band .. " - ~" .. pctText .. " " .. v.tag, r, g, b)
        end
    end

    -- a notable sighting marks the spot regardless of any option but autoMark
    RUN.Waypoint.autoMarkFor(info)

    pcall(tooltip.Show, tooltip)
end

-- Modern tooltip pipeline when present (mainline 12.x API), classic hook as
-- fallback - both are post-hooks on the shared GameTooltip: display-only.
if _G.TooltipDataProcessor and _G.Enum and _G.Enum.TooltipDataType then
    _G.TooltipDataProcessor.AddTooltipPostCall(_G.Enum.TooltipDataType.Unit, inject)
elseif _G.GameTooltip and _G.GameTooltip.HookScript then
    _G.GameTooltip:HookScript("OnTooltipSetUnit", inject)
end

return Tooltip
