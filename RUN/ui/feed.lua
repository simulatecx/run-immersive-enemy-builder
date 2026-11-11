-- The death feed: a Hardcore-addon-style scrolling list of the deaths RUN HEARS
-- over the shared death-ping channel (model/deathping.lua). The "living world"
-- the owner asked for - every player felled by a creature, somewhere on your
-- realm, scrolls past here. Monster-centric by default (no player names unless
-- the eulogy option is on; names are chosen handles/characters, never realm/
-- account). Own frame on UIParent, draggable + lockable via /ra move (the shared
-- validAnchorPos pattern - never anchored to a Blizzard frame, the taint law),
-- skinned by ui/skin.lua, gated by `deathFeed`. Lines fade after a window and the
-- frame hides when empty, all driven by the firewall ticker. Display-only.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Feed = {}
RUN.Feed = Feed

local MAX_LINES = 6     -- most recent deaths shown at once
local LINE_TTL = 30     -- seconds a line lives before it fades out

-- Pure: the feed line text (headless-tested). Monster-centric unless eulogy is on.
function Feed.line(creature, bracket, zone, total, eulogy, who)
    creature = tostring(creature or "An enemy")
    local lvl = (tonumber(bracket) and tonumber(bracket) > 0) and ("level " .. bracket .. " ") or ""
    local where = (zone and zone ~= "") and (" in " .. zone) or ""
    local tally = (tonumber(total) and tonumber(total) > 0) and (" (" .. total .. " slain)") or ""
    if eulogy and who and who ~= "" then
        return who .. " fell to " .. creature .. where .. tally
    end
    return creature .. " slew a " .. lvl .. "hero" .. where .. tally
end

-- Pure: ring-buffer insert, newest-first, capped (headless-tested).
function Feed.ring(list, entry, cap)
    table.insert(list, 1, entry)
    while #list > (tonumber(cap) or 1) do table.remove(list) end
    return list
end

-- Pure: a line is faded once it is older than the window (headless-tested).
function Feed.faded(when, now, ttl)
    return ((tonumber(now) or 0) - (tonumber(when) or 0)) > (tonumber(ttl) or LINE_TTL)
end

if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        check("feed line is monster-centric by default",
            Feed.line("Hogger", 10, "Elwynn", 5, false, "Bob")
                == "Hogger slew a level 10 hero in Elwynn (5 slain)")
        check("feed line names the fallen only with eulogy",
            Feed.line("Hogger", 10, "Elwynn", 5, true, "Bob")
                == "Bob fell to Hogger in Elwynn (5 slain)")
        check("feed line nil-safe + drops empty bits",
            Feed.line(nil, 0, nil, 0, false, nil) == "An enemy slew a hero")
        check("feed ring caps + keeps newest first", (function()
            local l = {}
            Feed.ring(l, "a", 3); Feed.ring(l, "b", 3)
            Feed.ring(l, "c", 3); Feed.ring(l, "d", 3)
            return #l == 3 and l[1] == "d" and l[3] == "b"
        end)())
        check("feed fade honours the window",
            Feed.faded(0, 31, 30) == true and Feed.faded(0, 29, 30) == false
            and Feed.faded(nil, 0, 30) == false)
    end)
end

-- Everything below wires the client.
if not _G.CreateFrame then return Feed end

local lines = {}   -- newest-first: { text, when, r, g, b }

local f = CreateFrame("Frame", "RUNDeathFeed", UIParent)
f:SetSize(300, 20 + MAX_LINES * 16)
f:SetFrameStrata("MEDIUM")
f:SetMovable(true)
f:EnableMouse(false)
f:RegisterForDrag("LeftButton")
f:Hide()

local border = RUN.Skin.panel(f)
f:SetAlpha(0.92)

local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
head:SetPoint("TOPLEFT", 10, -7)
head:SetText("Deaths heard")
RUN.Skin.title(head)

local rows = {}
for i = 1, MAX_LINES do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 10, -7 - i * 16)
    fs:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    fs:Hide()
    rows[i] = fs
end

local moving = false
f:SetScript("OnDragStart", function(self)
    RUN.safeCall("feed-drag", function()
        if RUN.Settings.get("feedLocked") then return end
        moving = true
        self:StartMoving()
    end)
end)
f:SetScript("OnDragStop", function(self)
    RUN.safeCall("feed-drop", function()
        self:StopMovingOrSizing()
        moving = false
        local p, _, _, x, y = self:GetPoint()
        local db = RUN.db()
        if type(db.ui) ~= "table" then db.ui = {} end
        db.ui.feedPos = { point = tostring(p or "LEFT"),
                          x = math.floor((tonumber(x) or 0) + 0.5),
                          y = math.floor((tonumber(y) or 0) + 0.5) }
    end)
end)

-- Saved drag position if set, else a safe default on UIParent (NEVER a Blizzard
-- frame - the taint law; same rule the panel + glow follow).
local function anchor()
    if moving then return end
    f:EnableMouse(not RUN.Settings.get("feedLocked"))
    f:ClearAllPoints()
    local db = RUN.db()
    local pos = RUN.validAnchorPos(db.ui and db.ui.feedPos)
    if pos then
        f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        f:SetPoint("LEFT", UIParent, "LEFT", 24, 120)
    end
end

local function render()
    local now = (_G.GetTime and _G.GetTime()) or 0
    local shown = 0
    for i = 1, MAX_LINES do
        local e = lines[i]
        local fs = rows[i]
        if e and not Feed.faded(e.when, now, LINE_TTL) then
            fs:SetText(e.text)
            fs:SetTextColor(e.r or 0.85, e.g or 0.8, e.b or 0.72)
            -- gentle fade over the last third of the window
            local age = now - (e.when or now)
            local a = (age > LINE_TTL * 0.66) and math.max(0.15, 1 - (age - LINE_TTL * 0.66) / (LINE_TTL * 0.34)) or 1
            fs:SetAlpha(a)
            fs:Show()
            shown = shown + 1
        else
            fs:Hide()
        end
    end
    if shown == 0 then f:Hide() else anchor(); f:Show() end
end

-- Record one heard death (called by deathping.onPing for EVERY ping; chat/alerts
-- stay notable-only, but the ambient feed shows them all). `mapID` -> zone name.
function Feed.add(creature, bracket, mapID, total, who, tier)
    if not RUN.Settings.get("deathFeed") then return end
    local zone
    if mapID and _G.C_Map and _G.C_Map.GetMapInfo then
        local info = RUN.Guards and RUN.Guards.call(_G.C_Map.GetMapInfo, mapID)
        zone = type(info) == "table" and info.name or nil
    end
    local text = Feed.line(creature, bracket, zone, total,
        RUN.Settings.get("eulogy"), who)
    local r, g, b
    if tonumber(tier) and tonumber(tier) >= 1 then r, g, b = RUN.Notoriety.colorFor(tier) end
    Feed.ring(lines, { text = text, when = (_G.GetTime and _G.GetTime()) or 0,
                       r = r, g = g, b = b }, MAX_LINES)
    render()
end

-- Fade + hide on the shared firewall ticker (no per-line timers).
RUN.ticker("death-feed", 2, function()
    if #lines > 0 or f:IsShown() then render() end
end)

-- /ra feed: quick toggle (registered, not routed through init.lua).
if type(RUN.commands) == "table" then
    RUN.commands.feed = function()
        local on = not RUN.Settings.get("deathFeed")
        RUN.Settings.set("deathFeed", on)
        RUN.print("death feed " .. (on and "on" or "off"))
    end
end

return Feed
