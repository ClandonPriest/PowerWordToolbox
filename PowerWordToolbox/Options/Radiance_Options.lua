-- ============================================================
--  Power Word: Toolbox  |  Options/Radiance_Options.lua
--  Radiance charge tracker settings tab.
-- ============================================================

local _, PWT = ...
local UI      = PWT.UI
local C       = UI.C
local PAD     = UI.PAD
local FRAME_W = UI.FRAME_W

local radPanel = UI:AddTab("radiance", "Radiance Bars", 4)

-- ── Title ─────────────────────────────────────────────────

local radTitle = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
radTitle:SetPoint("TOPLEFT", radPanel, "TOPLEFT", PAD, -PAD)
radTitle:SetText("Power Word: Radiance")
radTitle:SetTextColor(C.text[1], C.text[2], C.text[3])

local radSub = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
radSub:SetPoint("TOPLEFT", radTitle, "BOTTOMLEFT", 0, -4)
radSub:SetText("Two charge bars that fill as Radiance comes off cooldown.")
radSub:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local radLine1 = UI:MakeLine(radPanel, C.border, 1)
radLine1:SetPoint("TOPLEFT",  radSub,   "BOTTOMLEFT",   0, -8)
radLine1:SetPoint("TOPRIGHT", radPanel, "TOPRIGHT", -PAD, -8)

-- ── Bright Pupil (auto-detected) ──────────────────────────

local brightPupilStatusLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
brightPupilStatusLabel:SetPoint("TOPLEFT", radLine1, "BOTTOMLEFT", 2, -10)
brightPupilStatusLabel:SetText("Cooldown: detecting...")
brightPupilStatusLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local brightPupilDesc = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
brightPupilDesc:SetPoint("TOPLEFT", brightPupilStatusLabel, "BOTTOMLEFT", 0, -4)
brightPupilDesc:SetWidth(FRAME_W - PAD * 2)
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

-- ── Bar Size ──────────────────────────────────────────────

local barSizeHeader = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
barSizeHeader:SetPoint("TOPLEFT", radLine2, "BOTTOMLEFT", 0, -12)
barSizeHeader:SetText("Bar Size")
barSizeHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

-- Width
local barWidthLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
barWidthLabel:SetPoint("TOPLEFT", barSizeHeader, "BOTTOMLEFT", 0, -10)
barWidthLabel:SetText("Width:")
barWidthLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local barWidthSlider = CreateFrame("Slider", nil, radPanel, "OptionsSliderTemplate")
barWidthSlider:SetSize(160, 16)
barWidthSlider:SetPoint("LEFT", barWidthLabel, "RIGHT", 8, 0)
barWidthSlider:SetMinMaxValues(100, 400)
barWidthSlider:SetValueStep(10)
barWidthSlider:SetObeyStepOnDrag(true)
barWidthSlider.Low:SetText("100")
barWidthSlider.High:SetText("400")
barWidthSlider.Text:SetText("")
barWidthSlider:SetScript("OnValueChanged", function(self, val)
    val = math.floor(val / 10 + 0.5) * 10
    if PWT.db and PWT.db.radiance then PWT.db.radiance.barWidth = val end
    self.Text:SetText(tostring(val) .. "px")
    if PWT.Radiance then PWT.Radiance:RecreateWidget() end
end)

-- Height
local barHeightLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
barHeightLabel:SetPoint("TOPLEFT", barWidthLabel, "BOTTOMLEFT", 0, -26)
barHeightLabel:SetText("Height:")
barHeightLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local barHeightSlider = CreateFrame("Slider", nil, radPanel, "OptionsSliderTemplate")
barHeightSlider:SetSize(160, 16)
barHeightSlider:SetPoint("LEFT", barHeightLabel, "RIGHT", 8, 0)
barHeightSlider:SetMinMaxValues(8, 48)
barHeightSlider:SetValueStep(2)
barHeightSlider:SetObeyStepOnDrag(true)
barHeightSlider.Low:SetText("8")
barHeightSlider.High:SetText("48")
barHeightSlider.Text:SetText("")
barHeightSlider:SetScript("OnValueChanged", function(self, val)
    val = math.floor(val / 2 + 0.5) * 2
    if PWT.db and PWT.db.radiance then PWT.db.radiance.barHeight = val end
    self.Text:SetText(tostring(val) .. "px")
    if PWT.Radiance then PWT.Radiance:RecreateWidget() end
end)

local radLine3 = UI:MakeLine(radPanel, C.border, 1)
radLine3:SetPoint("TOPLEFT",  barHeightLabel, "BOTTOMLEFT",  0, -22)
radLine3:SetPoint("TOPRIGHT", radPanel, "TOPRIGHT", -PAD, -22)

-- ── Display ───────────────────────────────────────────────

local displayHeader = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
displayHeader:SetPoint("TOPLEFT", radLine3, "BOTTOMLEFT", 0, -12)
displayHeader:SetText("Display")
displayHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

-- ── Color Pickers ─────────────────────────────────────────

-- Helper: creates a 22x22 clickable color swatch that opens ColorPickerFrame.
-- onChanged(r, g, b) is called in real-time and on cancel/accept.
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
            swatchFunc  = function()
                applyColor(ColorPickerFrame:GetColorRGB())
            end,
            cancelFunc  = function(prev)
                applyColor(prev.r, prev.g, prev.b)
            end,
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

-- Bar fill color
local barColorLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
barColorLabel:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -12)
barColorLabel:SetText("Bar fill color:")
barColorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local barColorSwatch = MakeColorSwatch(radPanel, 1.0, 0.82, 0.0, function(r, g, b)
    if PWT.db and PWT.db.radiance then
        PWT.db.radiance.barColor = {r, g, b}
        if PWT.Radiance then PWT.Radiance:UpdateColors() end
    end
end)
barColorSwatch:SetPoint("LEFT", barColorLabel, "RIGHT", 8, 0)

-- Show countdown timer checkbox
local showTimerCheck = CreateFrame("CheckButton", nil, radPanel, "UICheckButtonTemplate")
showTimerCheck:SetPoint("TOPLEFT", barColorLabel, "BOTTOMLEFT", -2, -10)
showTimerCheck.text:SetText("Show countdown timer")
showTimerCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])

local showTimerDesc = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
showTimerDesc:SetPoint("TOPLEFT", showTimerCheck, "BOTTOMLEFT", 26, -2)
showTimerDesc:SetWidth(FRAME_W - PAD * 2 - 30)
showTimerDesc:SetJustifyH("LEFT")
showTimerDesc:SetText("Shows seconds remaining on the actively recharging bar.")
showTimerDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Timer text color
local textColorLabel = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
textColorLabel:SetPoint("TOPLEFT", showTimerDesc, "BOTTOMLEFT", -26, -10)
textColorLabel:SetText("Timer text color:")
textColorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local textColorSwatch = MakeColorSwatch(radPanel, 1.0, 1.0, 1.0, function(r, g, b)
    if PWT.db and PWT.db.radiance then
        PWT.db.radiance.textColor = {r, g, b}
        if PWT.Radiance then PWT.Radiance:UpdateColors() end
    end
end)
textColorSwatch:SetPoint("LEFT", textColorLabel, "RIGHT", 8, 0)

local function UpdateTextColorPickerState()
    local on = showTimerCheck:GetChecked()
    textColorSwatch:SetEnabled2(on)
    textColorLabel:SetTextColor(
        on and C.textMuted[1] or C.textMuted[1] * 0.5,
        on and C.textMuted[2] or C.textMuted[2] * 0.5,
        on and C.textMuted[3] or C.textMuted[3] * 0.5)
end

local colorResetBtn = CreateFrame("Button", nil, radPanel, "UIPanelButtonTemplate")
colorResetBtn:SetSize(90, 22)
colorResetBtn:SetPoint("TOPLEFT", textColorLabel, "BOTTOMLEFT", 2, -10)
colorResetBtn:SetText("Reset Colors")
colorResetBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.radiance) then return end
    PWT.db.radiance.barColor  = {1.0, 0.82, 0.0}
    PWT.db.radiance.textColor = {1.0, 1.0, 1.0}
    barColorSwatch:SetColor(1.0, 0.82, 0.0)
    textColorSwatch:SetColor(1.0, 1.0, 1.0)
    if PWT.Radiance then PWT.Radiance:UpdateColors() end
end)

showTimerCheck:SetScript("OnClick", function(self)
    PWT.db.radiance.showTimer = self:GetChecked()
    UpdateTextColorPickerState()
end)

local radLine4 = UI:MakeLine(radPanel, C.border, 1)
radLine4:SetPoint("TOPLEFT",  colorResetBtn, "BOTTOMLEFT", -2, -12)
radLine4:SetPoint("TOPRIGHT", radPanel, "TOPRIGHT", -PAD, -12)

-- ── Position ──────────────────────────────────────────────

local posHeader = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
posHeader:SetPoint("TOPLEFT", radLine4, "BOTTOMLEFT", 0, -12)
posHeader:SetText("Position")
posHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

local radLocked  = true
local radLockBtn  -- forward ref (used in enable check script above)

radLockBtn = CreateFrame("Button", nil, radPanel, "UIPanelButtonTemplate")
radLockBtn:SetSize(120, 24)
radLockBtn:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -8)
radLockBtn:SetText("Unlock to Move")
radLockBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.radiance and PWT.db.radiance.enabled) then
        PWT:Print("Enable the tracker first.")
        return
    end
    radLocked = not radLocked
    if PWT.Radiance then
        PWT.Radiance:ShowWidget()
        PWT.Radiance:SetMovable(not radLocked)
    end
    if not radLocked then
        radLockBtn:SetText("Lock Position")
        radLockBtn:GetFontString():SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
    else
        radLockBtn:SetText("Unlock to Move")
        radLockBtn:GetFontString():SetTextColor(1, 1, 1)
    end
end)

local radResetBtn = CreateFrame("Button", nil, radPanel, "UIPanelButtonTemplate")
radResetBtn:SetSize(110, 24)
radResetBtn:SetPoint("LEFT", radLockBtn, "RIGHT", 8, 0)
radResetBtn:SetText("Reset Position")
radResetBtn:SetScript("OnClick", function()
    if PWT.Radiance then PWT.Radiance:ResetPosition() end
    PWT:Print("Radiance bar position reset.")
end)

local posDesc = radPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
posDesc:SetPoint("TOPLEFT", radLockBtn, "BOTTOMLEFT", 0, -4)
posDesc:SetWidth(FRAME_W - PAD * 2)
posDesc:SetJustifyH("LEFT")
posDesc:SetText("Unlock the bar to drag it anywhere on screen, then lock to save the position.")
posDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ── Sync ─────────────────────────────────────────────────

function UI:SyncRadiance()
    if not PWT.db or not PWT.db.radiance then return end
    local db = PWT.db.radiance
    showTimerCheck:SetChecked(db.showTimer)
    barWidthSlider:SetValue(db.barWidth   or 220)
    barHeightSlider:SetValue(db.barHeight or 18)
    local bc = db.barColor  or {1.0, 0.82, 0.0}
    local tc = db.textColor or {1.0, 1.0, 1.0}
    barColorSwatch:SetColor(bc[1], bc[2], bc[3])
    textColorSwatch:SetColor(tc[1], tc[2], tc[3])
    UpdateTextColorPickerState()
    UI:UpdateBrightPupilStatus()
    -- Reset lock button state when tab opens
    radLocked = true
    radLockBtn:SetText("Unlock to Move")
    radLockBtn:GetFontString():SetTextColor(1, 1, 1)
    if PWT.Radiance then PWT.Radiance:SetMovable(false) end
end
