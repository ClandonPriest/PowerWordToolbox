-- Power Word: Toolbox | Modules/Radiance.lua

local _, PWT = ...

PWT.Radiance = {}
local Radiance = PWT.Radiance

-- Constants

local RADIANCE_SPELL_ID      = 194509
local BRIGHT_PUPIL_SPELL_ID  = 390669
local RADIANCE_CD_BASE       = 18   -- seconds, no Bright Pupil
local RADIANCE_CD_BRIGHT     = 15   -- seconds, with Bright Pupil
local RADIANCE_MAX_CHARGES   = 2
local RADIANCE_TICK          = 0.05 -- 20fps update rate during recharge

-- State

local charges       = RADIANCE_MAX_CHARGES
local rechargeStart = 0          -- GetTime() when the current recharge chain began
local brightPupil      = false   -- auto-detected from talent API
local detectedTalent   = nil     -- "Bright Pupil", "Enduring Luminescence", or nil
local widget        = nil

-- OnUpdate performance state
local radElapsed      = 0      -- tick accumulator for recharge throttle
local lastChargeState = -1     -- detects full-charge transition to flush bars once
local lastTimerStr    = ""     -- dirty check: only call SetText when display value changes
local lastLWidth      = -1     -- dirty check: last rendered left fill width in px
local lastRWidth      = -1     -- dirty check: last rendered right fill width in px

-- Helpers

local function GetDuration()
    return brightPupil and RADIANCE_CD_BRIGHT or RADIANCE_CD_BASE
end

-- Returns the spell name of the purchased talent at the given node, or nil.
-- pcall guards each node against tainted/secret values aborting the scan.
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
-- Accepts the current timestamp to avoid a redundant GetTime() call per frame.
local function TickCharges(now)
    if charges >= RADIANCE_MAX_CHARGES then return end
    local duration = GetDuration()
    local elapsed  = now - rechargeStart
    if elapsed >= duration then
        charges = charges + 1
        if charges < RADIANCE_MAX_CHARGES then
            -- Advance the anchor so the next charge recharges sequentially.
            rechargeStart = rechargeStart + duration
        end
    end
end

-- Returns leftFill (0-1), rightFill (0-1), timeRemaining (seconds).
-- Left bar  = charge 1 (first to come back when both are spent).
-- Right bar = charge 2 (second to come back, or recharging when only 1 is spent).
-- Accepts the current timestamp so GetTime() is called once per tick, not three times.
local function GetBarFills(now)
    TickCharges(now)
    local duration = GetDuration()
    local elapsed  = now - rechargeStart
    local progress = math.min(elapsed / duration, 1)
    local timeLeft = math.max(0, duration - elapsed)

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

-- Charge Tracking

Radiance.debugCasts = false

local EVANGELISM_SPELL_ID = 472433

-- Set to nil by Evangelism in the same frame to suppress pending consumption.
local pendingRadianceTime = nil

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

-- Widget

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
    f:SetScript("OnUpdate", function(self, delta)
        if not (PWT.db and PWT.db.radiance and PWT.db.radiance.enabled) then return end

        -- Full skip when both charges are full — the dominant idle state.
        -- On the one transition frame where charges just became full, flush bars
        -- to 100% and hide the timer, then do nothing until a charge is spent.
        if charges >= RADIANCE_MAX_CHARGES then
            if lastChargeState ~= RADIANCE_MAX_CHARGES then
                local lW = leftBar:GetWidth()
                if lW and lW > 0 then leftFill:SetWidth(lW) end
                local rW = rightBar:GetWidth()
                if rW and rW > 0 then rightFill:SetWidth(rW) end
                timerText:Hide()
                lastChargeState = RADIANCE_MAX_CHARGES
                lastLWidth = lW or -1
                lastRWidth = lW or -1
                lastTimerStr = ""
            end
            return
        end

        -- Throttle bar updates to RADIANCE_TICK (20fps) while recharging.
        radElapsed = radElapsed + delta
        if radElapsed < RADIANCE_TICK then return end
        radElapsed = 0
        lastChargeState = charges

        -- Single GetTime() call — passed into both TickCharges and GetBarFills.
        local now = GetTime()
        local lPct, rPct, timeLeft = GetBarFills(now)

        -- Only call SetWidth when the rendered pixel width has meaningfully changed.
        local lW = leftBar:GetWidth()
        if lW and lW > 0 then
            local newLW = math.max(0.01, lW * lPct)
            if math.abs(newLW - lastLWidth) > 0.5 then
                leftFill:SetWidth(newLW)
                lastLWidth = newLW
            end
        end

        local rW = rightBar:GetWidth()
        if rW and rW > 0 then
            local newRW = math.max(0.01, rW * rPct)
            if math.abs(newRW - lastRWidth) > 0.5 then
                rightFill:SetWidth(newRW)
                lastRWidth = newRW
            end
        end

        if PWT.db.radiance.showTimer and timeLeft > 0.05 then
            -- Reanchor only when the recharging charge slot changes.
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
            -- Only call SetText when the formatted string actually changes.
            local timerStr = string.format("%.1f", timeLeft)
            if timerStr ~= lastTimerStr then
                timerText:SetText(timerStr)
                lastTimerStr = timerStr
            end
            timerText:Show()
        else
            timerText:Hide()
            lastTimerStr = ""
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
    radElapsed      = 0
    lastChargeState = -1
    lastTimerStr    = ""
    lastLWidth      = -1
    lastRWidth      = -1
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

-- Event Handlers

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
