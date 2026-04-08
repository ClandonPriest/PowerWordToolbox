-- ============================================================
--  Power Word: Toolbox  |  Modules/Atonement.lua
--  Atonement aura tracking and HUD widget for Disc Priests.
-- ============================================================

local _, PWT = ...

PWT.Atonement = {}
local AT = PWT.Atonement

-- ============================================================
--  Constants
-- ============================================================

local ATONEMENT_ID = 194384
local AT_TICK      = 0.1

-- ============================================================
--  State
-- ============================================================

local atTable   = {}  -- [unitGUID] = expirationTime
local atElapsed = 0

-- ============================================================
--  Scanning
-- ============================================================

local function GetGroupUnits()
    local units = {}
    local n = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, n do units[#units+1] = "raid"..i end
    else
        units[#units+1] = "player"
        for i = 1, n do units[#units+1] = "party"..i end
    end
    return units
end

function AT:ScanUnit(unit)
    if not UnitExists(unit) then return end
    -- Only scan group-relevant units — ignore nameplates, focus, target, etc.
    if not (unit == "player" or unit:match("^party%d") or unit:match("^raid%d")) then return end
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then
        PWT:Debug("AT:ScanUnit: no readable GUID for unit " .. tostring(unit) .. " — skipping.", "atonement")
        return
    end

    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        local spellIdSecret  = issecretvalue(aura.spellId)
        local nameSecret     = issecretvalue(aura.name)
        local expirySecret   = issecretvalue(aura.expirationTime)
        local sourceSecret   = issecretvalue(aura.sourceUnit)

        if not spellIdSecret and aura.spellId == ATONEMENT_ID then
            if sourceSecret then
                PWT:Debug("AT:ScanUnit: Atonement spellId matched on " .. unit .. " but sourceUnit is secret.", "atonement")
            elseif not (aura.sourceUnit and UnitIsUnit(aura.sourceUnit, "player")) then
                PWT:Debug("AT:ScanUnit: Atonement on " .. unit .. " is from another caster, ignoring.", "atonement")
            elseif expirySecret then
                PWT:Debug("AT:ScanUnit: Atonement on " .. unit .. " matched but expirationTime is secret.", "atonement")
            else
                PWT:Debug("AT:ScanUnit: Atonement (spellId) registered on " .. unit, "atonement")
                atTable[guid] = aura.expirationTime
                return
            end
        elseif not nameSecret and aura.name == "Atonement" then
            if sourceSecret then
                PWT:Debug("AT:ScanUnit: Atonement name matched on " .. unit .. " but sourceUnit is secret.", "atonement")
            elseif not (aura.sourceUnit and UnitIsUnit(aura.sourceUnit, "player")) then
                PWT:Debug("AT:ScanUnit: Atonement (name fallback) on " .. unit .. " is from another caster.", "atonement")
            elseif expirySecret then
                PWT:Debug("AT:ScanUnit: Atonement (name fallback) on " .. unit .. " but expirationTime is secret.", "atonement")
            else
                PWT:Debug("AT:ScanUnit: Atonement (name fallback) registered on " .. unit, "atonement")
                atTable[guid] = aura.expirationTime
                return
            end
        end
        i = i + 1
    end
    -- Atonement not found — clear entry only if guid is usable as a key
    if not issecretvalue(guid) then
        atTable[guid] = nil
    end
end

function AT:ScanAll()
    wipe(atTable)
    local units = GetGroupUnits()
    PWT:Debug("AT:ScanAll: scanning " .. #units .. " units.", "atonement")
    for _, unit in ipairs(units) do
        self:ScanUnit(unit)
    end
    local count = 0
    for _ in pairs(atTable) do count = count + 1 end
    PWT:Debug("AT:ScanAll: found " .. count .. " active Atonement(s).", "atonement")
end

function AT:GetCount()
    local count = 0
    for _ in pairs(atTable) do count = count + 1 end
    return count
end

local function GetCountAndLowest()
    local count  = 0
    local lowest = math.huge
    local now    = GetTime()
    for guid, expiry in pairs(atTable) do
        if not issecretvalue(expiry) then
            local remaining = expiry - now
            if remaining > 0 then
                count = count + 1
                if remaining < lowest then lowest = remaining end
            else
                atTable[guid] = nil
            end
        end
    end
    if lowest == math.huge then lowest = 0 end
    return count, lowest
end

-- ============================================================
--  Widget
-- ============================================================

local widget    = CreateFrame("Frame", "PWT_AtonementWidget", UIParent)
local widgetBg  = widget:CreateTexture(nil, "BACKGROUND")
local countNum  = widget:CreateFontString(nil, "OVERLAY")
local lowestNum = widget:CreateFontString(nil, "OVERLAY")

AT.widget = widget

widget:SetFrameStrata("MEDIUM")
widget:SetClampedToScreen(true)
widget:SetMovable(true)
widget:EnableMouse(true)
widget:RegisterForDrag("LeftButton")
widget:SetScript("OnDragStart", function(self) self:StartMoving() end)
widget:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    if PWT.db then
        PWT.db.atonement.posX = x
        PWT.db.atonement.posY = y
    end
end)
widget:SetScript("OnEnter", function(self)
    if PWT.db and not PWT.db.atonement.locked then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffcc99ffAtonement Tracker|r")
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end
end)
widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

widgetBg:SetAllPoints(widget)
widgetBg:SetColorTexture(0.15, 0.15, 0.15, 0.45)

countNum:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
countNum:SetPoint("TOP", widget, "TOP", 0, -4)
countNum:SetText("0")
countNum:SetTextColor(1.0, 0.9, 1.0)

lowestNum:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
lowestNum:SetPoint("TOP", countNum, "BOTTOM", 0, -2)
lowestNum:SetText("--")
lowestNum:SetTextColor(1.0, 0.85, 0.4)

widget:SetScript("OnUpdate", function(self, delta)
    -- Mouse cursor follow runs every frame for smooth tracking
    if PWT.db and PWT.db.atonement.mouseFollow then
        local cx, cy = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        local anchor = PWT.db.atonement.mouseAnchor or "TOPLEFT"
        -- The saved anchor describes where the widget appears relative to the
        -- cursor (e.g. "TOPLEFT" = widget is above-left of cursor).  SetPoint's
        -- first arg is the corner of the widget that sits AT the cursor, so we
        -- need the geometrically opposite corner.
        local OPPOSITE = {
            TOPLEFT     = "BOTTOMRIGHT",
            TOPRIGHT    = "BOTTOMLEFT",
            BOTTOMLEFT  = "TOPRIGHT",
            BOTTOMRIGHT = "TOPLEFT",
        }
        self:ClearAllPoints()
        self:SetPoint(OPPOSITE[anchor] or "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    end

    atElapsed = atElapsed + delta
    if atElapsed < AT_TICK then return end
    atElapsed = 0
    if not PWT.db or not PWT.db.atonement.enabled then return end
    local count, lowest = GetCountAndLowest()
    countNum:SetText(tostring(count))
    if PWT.db.atonement.showLowest then
        lowestNum:Show()
        if count > 0 and lowest > 0 then
            if lowest <= 3 then
                lowestNum:SetTextColor(1.0, 0.3, 0.3)
            elseif lowest <= 6 then
                lowestNum:SetTextColor(1.0, 0.75, 0.2)
            else
                lowestNum:SetTextColor(1.0, 0.85, 0.4)
            end
            lowestNum:SetText(string.format("%.1f", lowest))
        else
            lowestNum:SetTextColor(0.5, 0.5, 0.55)
            lowestNum:SetText("--")
        end
    else
        lowestNum:Hide()
    end
end)

widget:Hide()

-- ============================================================
--  Widget Management
-- ============================================================

function AT:UpdateWidget()
    if not PWT.db then return end
    local cfg = PWT.db.atonement

    -- Save current pixel position (skip while mouse follow is active, or when
    -- we are restoring the pre-follow position and must not overwrite it)
    if not cfg.mouseFollow and not AT.skipNextPositionSave and widget:IsShown() then
        local left   = widget:GetLeft()
        local bottom = widget:GetBottom()
        local uiW    = UIParent:GetWidth()
        local uiH    = UIParent:GetHeight()
        if left and bottom then
            cfg.posX = left   + widget:GetWidth()  / 2 - uiW / 2
            cfg.posY = bottom + widget:GetHeight() / 2 - uiH / 2
        end
    end

    AT.skipNextPositionSave = nil  -- consume the one-shot flag

    -- Set fixed position only when not in mouse-follow mode
    if not cfg.mouseFollow then
        widget:ClearAllPoints()
        widget:SetPoint("CENTER", UIParent, "CENTER", cfg.posX or 0, cfg.posY or 200)
    end

    local fontPath  = (PWT.db.font and PWT.db.font ~= "") and PWT.db.font or "Fonts\\FRIZQT__.TTF"
    local countSize = cfg.countFontSize or 32
    local timerSize = cfg.timerFontSize or 20
    countNum:SetFont(fontPath,  countSize, "OUTLINE")
    lowestNum:SetFont(fontPath, timerSize, "OUTLINE")

    local w = math.max(countSize * 2.5, 70)
    local h = countSize + (cfg.showLowest and (timerSize + 10) or 0) + 16
    widget:SetSize(w, h)

    lowestNum:SetShown(cfg.showLowest)

    if not cfg.enabled then
        widget:Hide()
        return
    end
    widget:Show()

    if cfg.mouseFollow then
        -- Mouse is controlling position; hide background, disable drag interaction
        widgetBg:SetColorTexture(0, 0, 0, 0)
        widget:SetMovable(false)
        widget:EnableMouse(false)
    elseif cfg.locked then
        widgetBg:SetColorTexture(0, 0, 0, 0)
        widget:SetMovable(false)
        widget:EnableMouse(false)
    else
        widgetBg:SetColorTexture(0.15, 0.15, 0.15, 0.45)
        widget:SetMovable(true)
        widget:EnableMouse(true)
    end
end

function AT:HideWidget()
    widget:Hide()
end

function AT:PrintStatus()
    local count = self:GetCount()
    PWT:Print("Atonement: enabled=" .. tostring(PWT.db.atonement.enabled) ..
        "  activeCount=" .. count)
end

-- ============================================================
--  Event Handlers
-- ============================================================

function AT:OnLogin()
    self:UpdateWidget()
    self:ScanAll()
end