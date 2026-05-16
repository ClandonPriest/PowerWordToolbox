-- Power Word: Toolbox | Modules/Atonement.lua

local _, PWT = ...

PWT.Atonement = {}
local AT = PWT.Atonement

-- Constants

local ATONEMENT_ID = 194384
local AT_TICK      = 0.1

-- Precomputed opposite-corner map used by mouseFollow each frame.
-- Defined once at module level to avoid a table allocation per frame.
local OPPOSITE = {
    TOPLEFT     = "BOTTOMRIGHT",
    TOPRIGHT    = "BOTTOMLEFT",
    BOTTOMLEFT  = "TOPRIGHT",
    BOTTOMRIGHT = "TOPLEFT",
}

-- State

local atTable   = {}  -- [unitGUID] = expirationTime
local atElapsed = 0

-- Reusable buffer for expired GUIDs — avoids a per-tick allocation inside GetCountAndLowest.
local expired = {}

-- Scanning

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

-- String prefix check — avoids pattern compilation overhead on every UNIT_AURA call.
local function IsGroupUnit(unit)
    if unit == "player" then return true end
    local prefix = string.sub(unit, 1, 4)
    return prefix == "raid" or prefix == "part"
end

-- Validates source/expiry fields and registers the aura if usable. Returns true on success.
-- issecretvalue checks are deferred to here so they only run on an actual Atonement match.
local function TryRegisterAura(guid, aura)
    if issecretvalue(aura.sourceUnit) then return false end
    if not (aura.sourceUnit and UnitIsUnit(aura.sourceUnit, "player")) then return false end
    if issecretvalue(aura.expirationTime) then return false end
    atTable[guid] = aura.expirationTime
    return true
end

-- Count / Expiry

-- Defined before ScanAll/GetCount so both can reference it directly.
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
                -- Collect expired entries; removing during pairs iteration is unsafe.
                expired[#expired + 1] = guid
            end
        end
    end
    for i = 1, #expired do
        atTable[expired[i]] = nil
        expired[i] = nil
    end
    if lowest == math.huge then lowest = 0 end
    return count, lowest
end

function AT:ScanUnit(unit)
    if not UnitExists(unit) then return end
    if not IsGroupUnit(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then
        PWT:Debug("AT:ScanUnit: no readable GUID for " .. tostring(unit) .. " — skipping.", "atonement")
        return
    end

    -- Fast path: O(1) direct spellID lookup — skips iterating the full aura list.
    -- Guarded: GetAuraDataBySpellID is not available in all WoW versions.
    if C_UnitAuras.GetAuraDataBySpellID then
        local aura = C_UnitAuras.GetAuraDataBySpellID(unit, ATONEMENT_ID, "HELPFUL")
        if aura and not issecretvalue(aura.spellId) then
            if not TryRegisterAura(guid, aura) then
                atTable[guid] = nil
            end
            return
        end
    end

    -- Slow path: name-based scan — used when GetAuraDataBySpellID is unavailable,
    -- or when the spellId field is secret.
    -- issecretvalue is only checked after a name match, not on every aura.
    local i = 1
    while true do
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not a then break end
        if not issecretvalue(a.name) and a.name == "Atonement" then
            if not TryRegisterAura(guid, a) then
                atTable[guid] = nil
            end
            return
        end
        i = i + 1
    end

    atTable[guid] = nil
end

function AT:ScanAll()
    wipe(atTable)
    local units = GetGroupUnits()
    PWT:Debug("AT:ScanAll: scanning " .. #units .. " units.", "atonement")
    for _, unit in ipairs(units) do
        self:ScanUnit(unit)
    end
    local count = GetCountAndLowest()
    PWT:Debug("AT:ScanAll: found " .. count .. " active Atonement(s).", "atonement")
end

function AT:GetCount()
    return (GetCountAndLowest())
end

-- Widget

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
    if PWT.db then
        local x, y = self:GetCenter()
        PWT.db.atonement.posX = x - UIParent:GetWidth()  / 2
        PWT.db.atonement.posY = y - UIParent:GetHeight() / 2
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

-- Cached display state — SetText/SetTextColor/Show/Hide only called on actual change.
local lastCount      = -1
local lastLowestStr  = ""
local lastColorBand  = -1   -- 0=muted, 1=red, 2=orange, 3=yellow
local lastShowLowest = nil

widget:SetScript("OnUpdate", function(self, delta)
    if not (PWT.db and PWT.db.atonement and PWT.db.atonement.enabled) then return end

    if PWT.db.atonement.mouseFollow then
        local cx, cy = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        local anchor = PWT.db.atonement.mouseAnchor or "TOPLEFT"
        self:ClearAllPoints()
        self:SetPoint(OPPOSITE[anchor] or "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    end

    atElapsed = atElapsed + delta
    if atElapsed < AT_TICK then return end
    atElapsed = 0

    local count, lowest = GetCountAndLowest()

    if count ~= lastCount then
        countNum:SetText(tostring(count))
        lastCount = count
    end

    -- showLowest is a config value; only apply show/hide when it actually changes.
    local showLowest = PWT.db.atonement.showLowest
    if showLowest ~= lastShowLowest then
        lowestNum:SetShown(showLowest)
        lastShowLowest = showLowest
    end

    if showLowest then
        if count > 0 and lowest > 0 then
            local band = lowest <= 3 and 1 or (lowest <= 6 and 2 or 3)
            if band ~= lastColorBand then
                if band == 1 then
                    lowestNum:SetTextColor(1.0, 0.3, 0.3)
                elseif band == 2 then
                    lowestNum:SetTextColor(1.0, 0.75, 0.2)
                else
                    lowestNum:SetTextColor(1.0, 0.85, 0.4)
                end
                lastColorBand = band
            end
            local lowestStr = string.format("%.1f", lowest)
            if lowestStr ~= lastLowestStr then
                lowestNum:SetText(lowestStr)
                lastLowestStr = lowestStr
            end
        else
            if lastColorBand ~= 0 then
                lowestNum:SetTextColor(0.5, 0.5, 0.55)
                lastColorBand = 0
            end
            if lastLowestStr ~= "--" then
                lowestNum:SetText("--")
                lastLowestStr = "--"
            end
        end
    end
end)

widget:Hide()

-- Widget Management

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
    -- Reset display cache so OnUpdate re-applies state on next tick.
    lastCount      = -1
    lastLowestStr  = ""
    lastColorBand  = -1
    lastShowLowest = nil

    if not cfg.enabled then
        widget:Hide()
        return
    end
    widget:Show()

    if cfg.mouseFollow then
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

-- Event Handlers

function AT:OnLogin()
    self:UpdateWidget()
    self:ScanAll()
end
