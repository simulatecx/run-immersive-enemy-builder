-- Minimap blips: a tier-coloured dot on the minimap at the spot where a
-- rare / elite / notorious creature was seen (RareScanner-style, RUN's own
-- data). Fed by the nearby ping - vignette true coords when we have them, else
-- your position at the sighting - so "where is it?" has an answer on the map,
-- not just a banner. Session-transient (no SavedVariables change), tier-tinted,
-- fades after 10 minutes, current map only, behind the minimapPins option.
--
-- The placement MATH is pure + headless-tested (the hard part); the live wiring
-- reads the minimap zoom/rotation and routes its refresh through the firewall
-- ticker. Display-only; the stock minimap is never modified.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local MinimapPins = {}
RUN.MinimapPins = MinimapPins

-- Pure: the default round minimap's VISIBLE RADIUS in yards per zoom (0-5),
-- outdoor values (RUN pins are open-world rares/elites). Half the known
-- diameter table; indoors is a touch tighter but the direction stays right.
local OUTDOOR_DIAMETER = { [0] = 466.66, [1] = 400, [2] = 333.33,
                           [3] = 266.66, [4] = 200, [5] = 133.33 }
function MinimapPins.radiusYards(zoom)
    local d = OUTDOOR_DIAMETER[tonumber(zoom) or 0] or OUTDOOR_DIAMETER[3]
    return d / 2
end

-- Pure: project a target onto the minimap. (east, north) are yard offsets to
-- the target; radiusYards/radiusPixels size the minimap; when the minimap
-- rotates, `facing` (player facing, radians) turns the blip so facing is up.
-- Returns (x, y) pixel offset from centre, inRange, distanceYards. North-up
-- (rotate=false, the default) is exact; the rotating case applies FACING_SIGN
-- (flip it in-game if a rotating minimap ever mirrors the blips).
local FACING_SIGN = -1
function MinimapPins.project(east, north, radiusYards, radiusPixels, facing, rotate)
    east = tonumber(east) or 0
    north = tonumber(north) or 0
    radiusYards = tonumber(radiusYards) or 1
    if radiusYards <= 0 then radiusYards = 1 end
    radiusPixels = tonumber(radiusPixels) or 70
    local dist = math.sqrt(east * east + north * north)
    local ex, ny = east, north
    if rotate and facing then
        local a = FACING_SIGN * facing
        local c, s = math.cos(a), math.sin(a)
        ex = east * c - north * s
        ny = east * s + north * c
    end
    local scale = radiusPixels / radiusYards
    return ex * scale, ny * scale, dist <= radiusYards, dist
end

-- Pure: yard offsets (east, north) from player to target given normalized map
-- positions (0-1; y grows SOUTH in WoW map space) and the map's world size.
function MinimapPins.offsetYards(px, py, tx, ty, worldW, worldH)
    px, py = tonumber(px) or 0, tonumber(py) or 0
    tx, ty = tonumber(tx) or 0, tonumber(ty) or 0
    worldW, worldH = tonumber(worldW) or 0, tonumber(worldH) or 0
    return (tx - px) * worldW, (py - ty) * worldH   -- east, north
end

-- Selftests (registered; the placement math must be exact north-up + bounded).
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local function near(a, b) return math.abs(a - b) < 0.01 end
        check("pins radiusYards from zoom", near(MinimapPins.radiusYards(4), 100)
            and near(MinimapPins.radiusYards(0), 233.33))
        check("pins offsetYards east/north", (function()
            local e, n = MinimapPins.offsetYards(0.5, 0.5, 0.6, 0.4, 1000, 2000)
            return near(e, 100) and near(n, 200)   -- +east, +north (north = -y)
        end)())
        check("pins project north-up is exact", (function()
            local x, y, inR = MinimapPins.project(100, 0, 200, 70, 0, false)
            local x2, y2 = MinimapPins.project(0, 100, 200, 70, 0, false)
            return near(x, 35) and near(y, 0) and inR == true
                and near(x2, 0) and near(y2, 35)
        end)())
        check("pins project drops out-of-range", (function()
            local _, _, inR, d = MinimapPins.project(300, 0, 200, 70, 0, false)
            return inR == false and near(d, 300)
        end)())
        check("pins project rotates when the minimap rotates", (function()
            -- due-east target, facing east: with rotation it should swing off +x
            local x, y = MinimapPins.project(100, 0, 200, 70, math.pi / 2, true)
            return near(x, 0) and math.abs(y) > 10
        end)())
    end)
end

-- Everything below wires the client.
if not _G.CreateFrame then return MinimapPins end

local Guards = RUN.Guards
local pins = {}    -- [key] = { npc, name, mapID, x, y, when, tier }
local pool = {}    -- reusable blip textures on the Minimap

-- Record a sighting to blip. Called by the nearby ping with the best position
-- we have (vignette coords, else the player's spot).
function MinimapPins.add(npcID, name, mapID, x, y, tier)
    if not (mapID and tonumber(x) and tonumber(y)) then return end
    local key = npcID or name or (tostring(x) .. tostring(y))
    pins[key] = { npc = npcID, name = name, mapID = mapID,
                  x = tonumber(x), y = tonumber(y),
                  when = (_G.GetTime and _G.GetTime()) or 0, tier = tonumber(tier) or 0 }
end

local function blip(i)
    local t = pool[i]
    if t then return t end
    t = _G.Minimap:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    t:SetBlendMode("ADD")
    t:SetSize(15, 15)
    t:Hide()
    pool[i] = t
    return t
end

local function hideFrom(i)
    while pool[i] do pool[i]:Hide(); i = i + 1 end
end

local function update()
    local Minimap = _G.Minimap
    if not Minimap or not RUN.Settings.get("minimapPins") then return hideFrom(1) end

    local C_Map = _G.C_Map
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition
            and C_Map.GetMapWorldSize) then return hideFrom(1) end
    local mapID = Guards.call(C_Map.GetBestMapForUnit, "player")
    if not mapID then return hideFrom(1) end
    local pos = Guards.call(C_Map.GetPlayerMapPosition, mapID, "player")
    if not pos then return hideFrom(1) end
    local okXY, px, py = pcall(pos.GetXY, pos)
    if not (okXY and px) then return hideFrom(1) end
    local worldW, worldH = Guards.select(1, C_Map.GetMapWorldSize, mapID),
                           Guards.select(2, C_Map.GetMapWorldSize, mapID)
    if not (worldW and worldW > 0) then return hideFrom(1) end

    local zoom = (Minimap.GetZoom and select(2, pcall(Minimap.GetZoom, Minimap))) or 0
    local radiusY = MinimapPins.radiusYards(tonumber(zoom) or 0)
    local radiusP = (Minimap.GetWidth and (Minimap:GetWidth() / 2)) or 70
    local rotate = Guards.call(_G.GetCVar, "rotateMinimap") == "1"
    local facing = rotate and (Guards.call(_G.GetPlayerFacing) or 0) or 0
    local now = (_G.GetTime and _G.GetTime()) or 0

    local i = 0
    for key, p in pairs(pins) do
        if now - p.when > 600 then
            pins[key] = nil
        elseif p.mapID == mapID then
            local east, north = MinimapPins.offsetYards(px, py, p.x, p.y, worldW, worldH)
            local ox, oy, inRange = MinimapPins.project(east, north, radiusY, radiusP, facing, rotate)
            if inRange then
                i = i + 1
                local t = blip(i)
                local r, g, b = RUN.Notoriety.colorFor(p.tier)
                t:SetVertexColor(r, g, b)
                t:ClearAllPoints()
                t:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
                t:Show()
            end
        end
    end
    hideFrom(i + 1)
end

-- Refresh through the firewall ticker - fast enough to track your movement.
RUN.ticker("minimap-pins", 0.1, update)

return MinimapPins
