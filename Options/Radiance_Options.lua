-- Power Word: Toolbox | Options/Radiance_Options.lua

local _, PWT = ...
local UI      = PWT.UI
local C       = UI.C
local PAD     = UI.PAD
local CONTENT_W = UI.CONTENT_W

local radPanel = UI:AddTab("radiance", "Radiance Bars", 4)

local brightPupilStatusLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
brightPupilStatusLabel:SetPoint("TOPLEFT", radPanel, "TOPLEFT", 0, -PAD)
brightPupilStatusLabel:SetText("Cooldown: detecting...")
brightPupilStatusLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local brightPupilDesc = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
brightPupilDesc:SetPoint("TOPLEFT", brightPupilStatusLabel, "BOTTOMLEFT", 0, -4)
brightPupilDesc:SetWidth(CONTENT_W - PAD * 2)
brightPupilDesc:SetJustifyH("LEFT")
brightPupilDesc:SetText("Cooldown is detected automatically from your talents (18s baseline, 15s with Bright Pupil).")
brightPupilDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

function UI:UpdateBrightPupilStatus()
    if not PWT.Radiance then return end
    local talent = PWT.Radiance:GetDetectedTalent()
    if talent == "Bright Pupil" then
        brightPupilStatusLabel:SetText("|cff00ff00Bright Pupil detected|r  \226\128\148  15s cooldown")
    elseif talent == "Enduring Luminescence" then
        brightPupilStatusLabel:SetText("|cff00ff00Enduring Luminescence detected|r  \226\128\148  18s cooldown")
    else
        brightPupilStatusLabel:SetText("|cffaaaaaa Baseline|r  \226\128\148  18s cooldown")
    end
end

local radLine2 = UI:MakeLine(radPanel, C.border, 1)
radLine2:SetPoint("TOPLEFT",  brightPupilDesc, "BOTTOMLEFT",  0, -12)
radLine2:SetPoint("TOPRIGHT", radPanel, "TOPRIGHT", -PAD, -12)

-- ── Bar Size ───────────────────────────────────────────────────────────────

local barSizeHdr = UI:MakeSectionHeader(radPanel, radLine2, -12, "Bar Size")

local barWidthSlider = UI:MakeSlider(radPanel, "Width:", 100, 400, 10,
    function(val) return tostring(math.floor(val)) .. "px" end,
    function(val)
        if PWT.db and PWT.db.radiance then PWT.db.radiance.barWidth = val end
        if PWT.Radiance then PWT.Radiance:RecreateWidget() end
    end)
barWidthSlider:SetPoint("TOPLEFT", barSizeHdr, "BOTTOMLEFT", 0, -8)
barWidthSlider:SetPoint("RIGHT",   radPanel, "RIGHT", -PAD, 0)

local barHeightSlider = UI:MakeSlider(radPanel, "Height:", 8, 48, 2,
    function(val) return tostring(math.floor(val)) .. "px" end,
    function(val)
        if PWT.db and PWT.db.radiance then PWT.db.radiance.barHeight = val end
        if PWT.Radiance then PWT.Radiance:RecreateWidget() end
    end)
barHeightSlider:SetPoint("TOPLEFT", barWidthSlider, "BOTTOMLEFT", 0, -8)
barHeightSlider:SetPoint("RIGHT",   radPanel, "RIGHT", -PAD, 0)

local radLine3 = UI:MakeLine(radPanel, C.border, 1)
radLine3:SetPoint("TOPLEFT",  barHeightSlider, "BOTTOMLEFT",  0, -12)
radLine3:SetPoint("TOPRIGHT", radPanel, "TOPRIGHT", -PAD, -12)

-- ── Display ───────────────────────────────────────────────────────────────

local displayHdr = UI:MakeSectionHeader(radPanel, radLine3, -12, "Display")

local function MakeColorSwatch(parent, r, g, b, onChanged)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(22, 22)

    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(btn)
    border:SetColorTexture(0.35, 0.35, 0.35, 1)

    local fill = btn:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    fill:SetColorTexture(r, g, b, 1)
    btn.fill = fill

    local function applyColor(nr, ng, nb)
        r, g, b = nr, ng, nb
        fill:SetColorTexture(r, g, b, 1)
        onChanged(r, g, b)
    end

    btn:SetScript("OnClick", function()
        ColorPickerFrame:SetupColorPickerAndShow({
            r           = r,
            g           = g,
            b           = b,
            hasOpacity  = false,
            swatchFunc  = function() applyColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc  = function(prev) applyColor(prev.r, prev.g, prev.b) end,
        })
    end)

    function btn:SetColor(nr, ng, nb)
        r, g, b = nr, ng, nb
        fill:SetColorTexture(r, g, b, 1)
    end

    function btn:SetEnabled2(enabled)
        self:EnableMouse(enabled)
        self:SetAlpha(enabled and 1.0 or 0.35)
    end

    return btn
end

local barColorLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
barColorLabel:SetPoint("TOPLEFT", displayHdr, "BOTTOMLEFT", 0, -12)
barColorLabel:SetText("Bar fill color:")
barColorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local barColorSwatch = MakeColorSwatch(radPanel, 1.0, 0.82, 0.0, function(r, g, b)
    if PWT.db and PWT.db.radiance then
        PWT.db.radiance.barColor = {r, g, b}
        if PWT.Radiance then PWT.Radiance:UpdateColors() end
    end
end)
barColorSwatch:SetPoint("LEFT", barColorLabel, "RIGHT", 8, 0)

-- Forward declare so onChange can close over UpdateTextColorPickerState.
local UpdateTextColorPickerState

local showTimerCheck = UI:MakeCheckbox(radPanel, "Show countdown timer", nil, function(val)
    PWT.db.radiance.showTimer = val
    UpdateTextColorPickerState()
end)
showTimerCheck:SetPoint("TOPLEFT", barColorLabel, "BOTTOMLEFT", 0, -10)
showTimerCheck:SetPoint("RIGHT",   radPanel, "RIGHT", -PAD, 0)

local showTimerDesc = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
showTimerDesc:SetPoint("TOPLEFT", showTimerCheck, "BOTTOMLEFT", 22, -2)
showTimerDesc:SetWidth(CONTENT_W - PAD * 2 - 26)
showTimerDesc:SetJustifyH("LEFT")
showTimerDesc:SetText("Shows seconds remaining on the actively recharging bar.")
showTimerDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local textColorLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
textColorLabel:SetPoint("TOPLEFT", showTimerDesc, "BOTTOMLEFT", -22, -10)
textColorLabel:SetText("Timer text color:")
textColorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local textColorSwatch = MakeColorSwatch(radPanel, 1.0, 1.0, 1.0, function(r, g, b)
    if PWT.db and PWT.db.radiance then
        PWT.db.radiance.textColor = {r, g, b}
        if PWT.Radiance then PWT.Radiance:UpdateColors() end
    end
end)
textColorSwatch:SetPoint("LEFT", textColorLabel, "RIGHT", 8, 0)

-- Assigned after textColorSwatch and textColorLabel exist.
UpdateTextColorPickerState = function()
    local on = showTimerCheck.get()
    textColorSwatch:SetEnabled2(on)
    textColorLabel:SetTextColor(
        on and C.textMuted[1] or C.textMuted[1] * 0.5,
        on and C.textMuted[2] or C.textMuted[2] * 0.5,
        on and C.textMuted[3] or C.textMuted[3] * 0.5)
end

local colorResetBtn = UI:MakeButton(radPanel, "Reset Colors", function()
    if not (PWT.db and PWT.db.radiance) then return end
    PWT.db.radiance.barColor  = {1.0, 0.82, 0.0}
    PWT.db.radiance.textColor = {1.0, 1.0, 1.0}
    barColorSwatch:SetColor(1.0, 0.82, 0.0)
    textColorSwatch:SetColor(1.0, 1.0, 1.0)
    if PWT.Radiance then PWT.Radiance:UpdateColors() end
end, "default")
colorResetBtn:SetSize(100, 24)
colorResetBtn:SetPoint("TOPLEFT", textColorLabel, "BOTTOMLEFT", 0, -10)

local radLine4 = UI:MakeLine(radPanel, C.border, 1)
radLine4:SetPoint("TOPLEFT",  colorResetBtn, "BOTTOMLEFT",  0, -12)
radLine4:SetPoint("TOPRIGHT", radPanel, "TOPRIGHT", -PAD, -12)

-- ── Position ──────────────────────────────────────────────────────────────

local posHdr = UI:MakeSectionHeader(radPanel, radLine4, -12, "Position")

local radLockRow = UI:MakeLockResetRow(radPanel,
    function()  -- onLock
        if PWT.Radiance then PWT.Radiance:SetMovable(false) end
    end,
    function()  -- onUnlock
        if not (PWT.db and PWT.db.radiance and PWT.db.radiance.enabled) then
            PWT:Print("Enable the tracker first.")
            radLockRow.setLocked(true)
            return
        end
        if PWT.Radiance then
            PWT.Radiance:ShowWidget()
            PWT.Radiance:SetMovable(true)
        end
    end,
    function()  -- onReset
        if PWT.Radiance then PWT.Radiance:ResetPosition() end
        PWT:Print("Radiance bar position reset.")
    end,
    "Unlock to Move", "Lock Position")
radLockRow:SetPoint("TOPLEFT", posHdr, "BOTTOMLEFT", 0, -8)
radLockRow:SetPoint("RIGHT",   radPanel, "RIGHT", -PAD, 0)

local posDesc = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
posDesc:SetPoint("TOPLEFT", radLockRow, "BOTTOMLEFT", 0, -4)
posDesc:SetWidth(CONTENT_W - PAD * 2)
posDesc:SetJustifyH("LEFT")
posDesc:SetText("Unlock the bar to drag it anywhere on screen, then lock to save the position.")
posDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ── Sync ──────────────────────────────────────────────────────────────────

function UI:SyncRadiance()
    if not PWT.db or not PWT.db.radiance then return end
    local db = PWT.db.radiance
    showTimerCheck.set(db.showTimer)
    barWidthSlider.set(db.barWidth   or 220)
    barHeightSlider.set(db.barHeight or 18)
    local bc = db.barColor  or {1.0, 0.82, 0.0}
    local tc = db.textColor or {1.0, 1.0, 1.0}
    barColorSwatch:SetColor(bc[1], bc[2], bc[3])
    textColorSwatch:SetColor(tc[1], tc[2], tc[3])
    UpdateTextColorPickerState()
    UI:UpdateBrightPupilStatus()
    radLockRow.setLocked(true)
    if PWT.Radiance then PWT.Radiance:SetMovable(false) end
end
