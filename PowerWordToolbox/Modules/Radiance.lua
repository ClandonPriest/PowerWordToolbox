-- ============================================================
--  Power Word: Toolbox  |  Modules/Radiance.lua
--  Power Word: Radiance charge tracker.
--  Two side-by-side fill bars driven by cast-event timing.
-- ============================================================

local _, PWT = ...

PWT.Radiance = {}
local Radiance = PWT.Radiance

-- ============================================================
--  Constants
-- ============================================================

local RADIANCE_SPELL_ID      = 194509
local BRIGHT_PUPIL_SPELL_ID  = 390669
local RADIANCE_CD_BASE       = 18   -- seconds, no Bright Pupil
local RADIANCE_CD_BRIGHT     = 15   -- seconds, with Bright Pupil
local RADIANCE_MAX_CHARGES   = 2

-- ============================================================
--  State
-- ============================================================

local charges       = RADIANCE_MAX_CHARGES
local rechargeStart = 0          -- GetTime() when the current recharge chain began
local brightPupil      = false   -- auto-detected from talent API
local detectedTalent   = nil     -- "Bright Pupil", "Enduring Luminescence", or nil
local widget        = nil

-- ============================================================
--  Helpers
-- ============================================================

local function GetDuration()
    return brightPupil and RADIANCE_CD_BRIGHT or RADIANCE_CD_BASE
end

-- Walks the active talent config tree looking for a purchased node whose
-- spell name is "Bright Pupil".  Each node body is wrapped in pcall so a
-- secret/tainted value on any individual node doesn't abort the whole scan.
-- Returns the spell name of the purchased talent at the given node, or nil.
local function GetNodeTalentName(configID, nodeID)
    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
    if not nodeInfo or not nodeInfo.ranksPurchased
       or nodeInfo.ranksPurchased == 0
       or not nodeInfo.activeEntry then
        return nil
    end
    local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
    if not entryInfo or not entryInfo.definitionID then return nil end
    if not C_Traits.GetDefinitionInfo then return nil end
    local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
    if not defInfo or not defInfo.spellID then return nil end
    return C_Spell.GetSpellName(defInfo.spellID)
end

-- Returns the name of the active Radiance CD talent, or nil if neither is taken. 
local function ScanForRadianceTalent()
    if not (C_ClassTalents and C_Traits and C_Spell) then return nil end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    local treeID = specID and C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then return nil end
    local nodeIDs = C_Traits.GetTreeNodes(treeID)
    if not nodeIDs then return nil end

    for _, nodeID in ipairs(nodeIDs) do
        local ok, name = pcall(GetNodeTalentName, configID, nodeID)
        if ok and (name == "Bright Pupil" or name == "Enduring Luminescence") then
            return name
        end
    end
    return nil
end

function Radiance:DetectBrightPupil()
    local ok, talent = pcall(ScanForRadianceTalent)
    if not ok then return end
    detectedTalent = talent
    brightPupil    = (talent == "Bright Pupil")
    PWT:Debug("Radiance talent: " .. tostring(talent) .. "  duration=" .. GetDuration() .. "s", "radiance")
    if PWT.UI and PWT.UI.UpdateBrightPupilStatus then
        PWT.UI:UpdateBrightPupilStatus()
    end
end

function Radiance:GetDetectedTalent()
    return detectedTalent
end

-- Advance the charge state based on elapsed time.
-- Called every OnUpdate so charge restoration is never missed.
local function TickCharges()
    if charges >= RADIANCE_MAX_CHARGES then return end
    local duration = GetDuration()
    local elapsed  = GetTime() - rechargeStart
    if elapsed >= duration then
        charges = charges + 1
        PWT:Debug("Radiance charge restored. Charges: " .. charges, "radiance")
        if charges < RADIANCE_MAX_CHARGES then
            -- Advance the anchor so the next charge recharges sequentially.
            rechargeStart = rechargeStart + duration
        end
    end
end

-- Returns leftFill (0-1), rightFill (0-1), timeRemaining (seconds).
-- Left bar  = charge 1 (first to come back when both are spent).
-- Right bar = charge 2 (second to come back, or recharging when only 1 is spent).
local function GetBarFills()
    TickCharges()
    local duration = GetDuration()
    local progress = math.min((GetTime() - rechargeStart) / duration, 1)
    local timeLeft = math.max(0, duration - (GetTime() - rechargeStart))

    if charges >= 2 then
        return 1, 1, 0
    elseif charges == 1 then
        -- One charge available (left full); right is recharging.
        return 1, progress, timeLeft
    else
        -- Both charges spent; left is recharging, right is empty.
        return progress, 0, timeLeft
    end
end

-- ============================================================
--  Charge Tracking
-- ============================================================

-- ============================================================
--  DEBUG: spell cast logging
--  Set Radiance.debugCasts = true in-game to enable.
--  /run PWT.Radiance.debugCasts = true
--  /run PWT.Radiance.debugCasts = false
-- ============================================================
Radiance.debugCasts = false

local EVANGELISM_SPELL_ID = 472433

-- GetTime() of the most recently queued Radiance charge consumption.
-- Set to nil by Evangelism when it fires in the same frame to suppress it.
local pendingRadianceTime = nil

-- Combat log debug frame — only active when debugCasts is true.
-- Captures SPELL_CAST_SUCCESS for the player so we can see every
-- spell (including Evangelism and proc Radiances) with their source.
local debugCLEUFrame = CreateFrame("Frame")
debugCLEUFrame:SetScript("OnEvent", function()
    if not PWT.Radiance.debugCasts then return end
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName =
        CombatLogGetCurrentEventInfo()
    if subevent ~= "SPELL_CAST_SUCCESS" then return end
    local playerGUID = UnitGUID("player")
    if sourceGUID ~= playerGUID then return end
    PWT:Debug(string.format(
        "[CLEU] spellID=%d  name=%s  charges=%d  t=%.3f",
        spellID, spellName or "?", charges, GetTime()
    ), "radiance")
end)

function Radiance:SetDebugCasts(enabled)
    self.debugCasts = enabled
    if enabled then
        debugCLEUFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        PWT:Debug("[DEBUG] Combat log listener ON", "radiance")
    else
        debugCLEUFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        PWT:Debug("[DEBUG] Combat log listener OFF", "radiance")
    end
end

function Radiance:OnSpellCast(unit, spellID)
    if unit ~= "player" then return end

    -- ── DEBUG: log every UNIT_SPELLCAST_SUCCEEDED for the player ──
    if self.debugCasts then
        local spellName = C_Spell.GetSpellName(spellID) or "unknown"
        PWT:Debug(string.format(
            "[USCS] spellID=%d  name=%s  charges=%d  t=%.3f",
            spellID, spellName, charges, GetTime()
        ), "radiance")
    end

    if spellID == RADIANCE_SPELL_ID then
        -- Defer charge consumption by one frame. If Evangelism fires in the
        -- same frame (same GetTime()), it will nil out pendingRadianceTime
        -- and the deferred function will see the mismatch and bail out.
        local t = GetTime()
        pendingRadianceTime = t
        C_Timer.After(0, function()
            if pendingRadianceTime ~= t then
                PWT:Debug("Radiance charge suppressed (Evangelism proc).", "radiance")
                return
            end
            pendingRadianceTime = nil
            if charges == RADIANCE_MAX_CHARGES then
                rechargeStart = GetTime()
            end
            if charges > 0 then
                charges = charges - 1
            end
            PWT:Debug("Radiance cast. Charges now: " .. charges
                .. "  duration: " .. GetDuration() .. "s", "radiance")
        end)

    elseif spellID == EVANGELISM_SPELL_ID then
        -- Evangelism grants a free Radiance — cancel any pending charge
        -- consumption that fired in the same frame.
        if pendingRadianceTime == GetTime() then
            pendingRadianceTime = nil
        end
    end
end

-- ============================================================
--  Widget
-- ============================================================

function Radiance:CreateWidget()
    if widget then return end
    local db   = PWT.db.radiance
    local barW = db.barWidth  or 220
    local barH = db.barHeight or 18

    local f = CreateFrame("Frame", "PWT_RadianceWidget", UIParent)
    f:SetSize(barW, barH)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        PWT.db.radiance.posX = x - UIParent:GetWidth()  / 2
        PWT.db.radiance.posY = y - UIParent:GetHeight() / 2
    end)

    -- Saved position
    f:ClearAllPoints()
    if db.posX and db.posY then
        f:SetPoint("CENTER", UIParent, "CENTER", db.posX, db.posY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end

    -- ── Left bar frame (charge 1) ─────────────────────────
    -- Ends 2px left of centre so it never overlaps the divider.
    local leftBar = CreateFrame("Frame", nil, f)
    leftBar:SetPoint("TOPLEFT",     f, "TOPLEFT", 0,  0)
    leftBar:SetPoint("BOTTOMRIGHT", f, "BOTTOM",  -2, 0)

    local leftBg = leftBar:CreateTexture(nil, "BACKGROUND")
    leftBg:SetAllPoints(leftBar)
    leftBg:SetColorTexture(0.10, 0.08, 0.02, 1.0)

    local leftFill = leftBar:CreateTexture(nil, "ARTWORK")
    leftFill:SetPoint("TOPLEFT",    leftBar, "TOPLEFT",    0, 0)
    leftFill:SetPoint("BOTTOMLEFT", leftBar, "BOTTOMLEFT", 0, 0)
    leftFill:SetWidth(0.01)
    local bc = db.barColor or {1.0, 0.82, 0.0}
    leftFill:SetColorTexture(bc[1], bc[2], bc[3], 1.0)
    f.leftBar  = leftBar
    f.leftFill = leftFill

    -- ── Right bar frame (charge 2) ────────────────────────
    -- Starts 2px right of centre so it never overlaps the divider.
    local rightBar = CreateFrame("Frame", nil, f)
    rightBar:SetPoint("TOPLEFT",     f, "TOP",         2, 0)
    rightBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local rightBg = rightBar:CreateTexture(nil, "BACKGROUND")
    rightBg:SetAllPoints(rightBar)
    rightBg:SetColorTexture(0.10, 0.08, 0.02, 1.0)

    local rightFill = rightBar:CreateTexture(nil, "ARTWORK")
    rightFill:SetPoint("TOPLEFT",    rightBar, "TOPLEFT",    0, 0)
    rightFill:SetPoint("BOTTOMLEFT", rightBar, "BOTTOMLEFT", 0, 0)
    rightFill:SetWidth(0.01)
    rightFill:SetColorTexture(bc[1], bc[2], bc[3], 1.0)
    f.rightBar  = rightBar
    f.rightFill = rightFill

    -- ── Centre divider ────────────────────────────────────
    -- Own Frame at a higher level so it always renders above the bar children,
    -- remaining visible even when both fills are at 100%.
    local dividerFrame = CreateFrame("Frame", nil, f)
    dividerFrame:SetPoint("TOPLEFT",     f, "TOP",    -1, 0)
    dividerFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOM",  1, 0)
    dividerFrame:SetFrameLevel(f:GetFrameLevel() + 5)
    local divider = dividerFrame:CreateTexture(nil, "OVERLAY")
    divider:SetAllPoints(dividerFrame)
    divider:SetColorTexture(0, 0, 0, 1)

    -- ── Countdown text ────────────────────────────────────
    -- Must live in its own Frame above the bar child Frames,
    -- otherwise child Frames always render on top of parent FontStrings.
    local timerFrame = CreateFrame("Frame", nil, f)
    timerFrame:SetAllPoints(f)
    timerFrame:SetFrameLevel(f:GetFrameLevel() + 6)
    local timerText = timerFrame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    local tc = db.textColor or {1.0, 1.0, 1.0}
    timerText:SetTextColor(tc[1], tc[2], tc[3], 0.9)
    timerText:Hide()
    f.timerText = timerText

    -- ── OnUpdate ──────────────────────────────────────────
    local timerAnchorCharges = -1  -- sentinel: force first anchor
    f:SetScript("OnUpdate", function(self)
        if not (PWT.db and PWT.db.radiance) then return end

        local lPct, rPct, timeLeft = GetBarFills()

        local lW = leftBar:GetWidth()
        if lW and lW > 0 then
            leftFill:SetWidth(math.max(0.01, lW * lPct))
        end

        local rW = rightBar:GetWidth()
        if rW and rW > 0 then
            rightFill:SetWidth(math.max(0.01, rW * rPct))
        end

        if PWT.db.radiance.showTimer and timeLeft > 0.05 then
            -- Reanchor only when the recharging charge changes.
            if charges ~= timerAnchorCharges then
                timerText:ClearAllPoints()
                if charges == 0 then
                    -- Left bar recharging: pin to right edge of left bar (near divider).
                    timerText:SetPoint("RIGHT", timerFrame, "CENTER", -4, 0)
                else
                    -- Right bar recharging: pin to far right of widget.
                    timerText:SetPoint("RIGHT", timerFrame, "RIGHT", -4, 0)
                end
                timerAnchorCharges = charges
            end
            timerText:SetText(string.format("%.1f", timeLeft))
            timerText:Show()
        else
            timerText:Hide()
        end
    end)

    f:Hide()
    widget = f
    self:UpdateWidget()
end

function Radiance:RecreateWidget()
    if widget then
        widget:SetScript("OnUpdate", nil)
        widget:Hide()
        widget = nil
    end
    self:CreateWidget()
    if PWT.db and PWT.db.radiance and PWT.db.radiance.enabled and PWT.isDisc then
        self:ShowWidget()
    end
end

function Radiance:UpdateWidget()
    if not widget then return end
    local font = (PWT.db and PWT.db.font) or "Fonts\\FRIZQT__.TTF"
    if not pcall(function()
        widget.timerText:SetFont(font, 11, "OUTLINE")
    end) then
        widget.timerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    end
end

function Radiance:UpdateColors()
    if not widget then return end
    local db = PWT.db and PWT.db.radiance
    if not db then return end
    local bc = db.barColor  or {1.0, 0.82, 0.0}
    local tc = db.textColor or {1.0, 1.0, 1.0}
    widget.leftFill:SetColorTexture(bc[1], bc[2], bc[3], 1.0)
    widget.rightFill:SetColorTexture(bc[1], bc[2], bc[3], 1.0)
    widget.timerText:SetTextColor(tc[1], tc[2], tc[3], 0.9)
end

function Radiance:ShowWidget()
    if not widget then self:CreateWidget() end
    widget:Show()
end

function Radiance:HideWidget()
    if widget then widget:Hide() end
end

function Radiance:SetMovable(canMove)
    if not widget then return end
    widget:EnableMouse(canMove)
end

function Radiance:ResetPosition()
    if not widget then return end
    widget:ClearAllPoints()
    widget:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    PWT.db.radiance.posX = nil
    PWT.db.radiance.posY = nil
end

-- ============================================================
--  Event Handlers
-- ============================================================

function Radiance:OnLogin()
    self:DetectBrightPupil()
    self:CreateWidget()
    if PWT.db.radiance.enabled then
        self:ShowWidget()
    end
end

function Radiance:PrintStatus()
    PWT:Print("Radiance: enabled="   .. tostring(PWT.db.radiance.enabled) ..
        "  charges="    .. tostring(charges) ..
        "  brightPupil=" .. tostring(PWT.db.radiance.brightPupil) ..
        "  duration="   .. tostring(GetDuration()) .. "s")
end
