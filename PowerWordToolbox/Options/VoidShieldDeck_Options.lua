-- ============================================================
--  Power Word: Toolbox  |  Options/VoidShieldDeck_Options.lua
--  Void Shield deck tracker configuration tab.
-- ============================================================

local _, PWT = ...
local UI  = PWT.UI
local C   = UI.C
local PAD = UI.PAD
local FRAME_W = UI.FRAME_W

local vsPanel = UI:AddTab("voidshield", "Void Shield", 5)

-- ── Scroll wrapper ────────────────────────────────────────────
local vsScroll = CreateFrame("ScrollFrame", nil, vsPanel)
vsScroll:SetAllPoints(vsPanel)
vsScroll:EnableMouseWheel(true)
vsScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
end)

local vsContent = CreateFrame("Frame", nil, vsScroll)
vsContent:SetWidth(FRAME_W)
vsContent:SetHeight(1400)
vsScroll:SetScrollChild(vsContent)

-- ── Title ──────────────────────────────────────────────────────
local title = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
title:SetPoint("TOPLEFT", vsContent, "TOPLEFT", PAD, -PAD)
title:SetText("Void Shield Deck Tracker")
title:SetTextColor(C.text[1], C.text[2], C.text[3])

local sub = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
sub:SetText("Track remaining Void Shield deck cards and next Penance proc chance.")
sub:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local line1 = UI:MakeLine(vsContent, C.border, 1)
line1:SetPoint("TOPLEFT",  sub,      "BOTTOMLEFT",   0, -8)
line1:SetPoint("TOPRIGHT", vsContent, "TOPRIGHT", -PAD, -8)

-- ─────────────────────────────────────────────────────────────
--  Shared helpers
-- ─────────────────────────────────────────────────────────────

-- EditBox for a numeric font-size value (10–40).
local function MakeFontSizeBox(parent, dbKey)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(50, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(2)

    local function applyValue(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            val = math.max(10, math.min(40, val))
            self:SetText(tostring(val))
            if PWT.db and PWT.db.voidShieldDeck then
                PWT.db.voidShieldDeck[dbKey] = val
                if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
            end
        elseif PWT.db and PWT.db.voidShieldDeck then
            self:SetText(tostring(PWT.db.voidShieldDeck[dbKey] or 18))
        end
    end
    box:SetScript("OnEnterPressed", function(self) applyValue(self); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", applyValue)
    return box
end

-- ── Shared strata popup ───────────────────────────────────────

local STRATA_OPTIONS    = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
local STRATA_DROP_W     = 150
local STRATA_DROP_ROW_H = 20
local STRATA_DROP_H     = #STRATA_OPTIONS * STRATA_DROP_ROW_H + 8

local strataPopup = CreateFrame("Frame", "PWT_VSD_StrataDropPanel", UIParent)
strataPopup:SetSize(STRATA_DROP_W, STRATA_DROP_H)
strataPopup:SetFrameStrata("TOOLTIP")
strataPopup:SetFrameLevel(100)
strataPopup:Hide()
UI:MakeBg(strataPopup, {0.06, 0.06, 0.08, 0.98})
do
    local t = strataPopup:CreateTexture(nil, "OVERLAY")
    t:SetHeight(1); t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
    t:SetPoint("TOPLEFT", strataPopup, "TOPLEFT", 0, 0)
    t:SetPoint("TOPRIGHT", strataPopup, "TOPRIGHT", 0, 0)
    local b = strataPopup:CreateTexture(nil, "OVERLAY")
    b:SetHeight(1); b:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
    b:SetPoint("BOTTOMLEFT", strataPopup, "BOTTOMLEFT", 0, 0)
    b:SetPoint("BOTTOMRIGHT", strataPopup, "BOTTOMRIGHT", 0, 0)
end

local strataPopupRows   = {}
local strataPopupTarget = { btn = nil, dbKey = nil }

local strataDropWatcher = CreateFrame("Frame", nil, UIParent)
strataDropWatcher:SetAllPoints(UIParent)
strataDropWatcher:SetFrameStrata("DIALOG")
strataDropWatcher:EnableMouse(false)
strataDropWatcher:Hide()

local function HideStrataDropdown()
    strataPopup:Hide()
    strataDropWatcher:EnableMouse(false)
    strataDropWatcher:Hide()
end

local function PopulateStrataDropdown(dbKey, currentVal)
    for _, r in ipairs(strataPopupRows) do r:Hide() end
    wipe(strataPopupRows)

    for i, strata in ipairs(STRATA_OPTIONS) do
        local row = CreateFrame("Button", nil, strataPopup)
        row:SetSize(STRATA_DROP_W, STRATA_DROP_ROW_H)
        row:SetPoint("TOPLEFT", strataPopup, "TOPLEFT", 0, -4 - (i - 1) * STRATA_DROP_ROW_H)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        row.bg = rowBg

        local rowLbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        rowLbl:SetPoint("LEFT",  row, "LEFT",  8, 0)
        rowLbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rowLbl:SetJustifyH("LEFT")
        rowLbl:SetText(strata)

        local isSel = (strata == currentVal)
        rowBg:SetColorTexture(
            isSel and C.tabActive[1] or 0,
            isSel and C.tabActive[2] or 0,
            isSel and C.tabActive[3] or 0,
            isSel and C.tabActive[4] or 0)
        rowLbl:SetTextColor(
            isSel and C.textAccent[1] or C.text[1],
            isSel and C.textAccent[2] or C.text[2],
            isSel and C.textAccent[3] or C.text[3])

        row:SetScript("OnEnter", function(self)
            if strata ~= currentVal then
                self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6)
            end
        end)
        row:SetScript("OnLeave", function(self)
            local active = (strata == currentVal)
            self.bg:SetColorTexture(
                active and C.tabActive[1] or 0,
                active and C.tabActive[2] or 0,
                active and C.tabActive[3] or 0,
                active and C.tabActive[4] or 0)
        end)
        row:SetScript("OnClick", function()
            if PWT.db and PWT.db.voidShieldDeck then
                PWT.db.voidShieldDeck[dbKey] = strata
            end
            if strataPopupTarget.btn then
                strataPopupTarget.btn:GetFontString():SetText(strata)
            end
            if PWT.VoidShieldDeck then PWT.VoidShieldDeck:ApplyStrata() end
            HideStrataDropdown()
        end)

        row:Show()
        strataPopupRows[i] = row
    end
end

strataPopup:HookScript("OnShow", function()
    strataDropWatcher:EnableMouse(true)
    strataDropWatcher:Show()
    strataDropWatcher:SetScript("OnMouseDown", function(self)
        HideStrataDropdown()
    end)
end)

-- Creates a strata dropdown row (container Frame + label + button).
-- Anchors to anchorFrame BOTTOMLEFT with the given yOffset.
-- Returns the container Frame and the button.
local function MakeStrataRow(parent, anchor, yOffset, label, dbKey)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W - PAD * 2, 24)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 2)
    lbl:SetText(label)
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(130, 22)
    btn:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
    btn:GetFontString():SetText("MEDIUM")

    btn:SetScript("OnClick", function(self)
        if strataPopup:IsShown() and strataPopupTarget.btn == self then
            HideStrataDropdown()
            return
        end
        local currentVal = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck[dbKey]) or "MEDIUM"
        strataPopupTarget.btn   = self
        strataPopupTarget.dbKey = dbKey
        PopulateStrataDropdown(dbKey, currentVal)
        strataPopup:ClearAllPoints()
        strataPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        strataPopup:Show()
    end)

    return row, btn
end

-- ─────────────────────────────────────────────────────────────
--  Section helper: small header + horizontal rule
-- ─────────────────────────────────────────────────────────────

local function MakeSectionHeader(parent, anchor, yOffset, text)
    local hdr = parent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
    hdr:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    hdr:SetText(text)
    hdr:SetTextColor(C.text[1], C.text[2], C.text[3])

    local rule = UI:MakeLine(parent, C.border, 1)
    rule:SetPoint("TOPLEFT",  hdr,    "BOTTOMLEFT",   0, -4)
    rule:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -4)

    return hdr, rule
end

-- ─────────────────────────────────────────────────────────────
--  SECTION: Chance
-- ─────────────────────────────────────────────────────────────

local chanceHdr, chanceRule = MakeSectionHeader(vsContent, line1, -14, "Proc Chance")

local chanceCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
chanceCheck:SetPoint("TOPLEFT", chanceRule, "BOTTOMLEFT", 0, -10)
chanceCheck.text:SetText("Show proc chance")
chanceCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
chanceCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showChance = self:GetChecked()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

local chanceLabelCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
chanceLabelCheck:SetPoint("TOPLEFT", chanceCheck, "BOTTOMLEFT", 0, -4)
chanceLabelCheck.text:SetText("Show \"Chance:\" label text")
chanceLabelCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
chanceLabelCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showChanceLabel = self:GetChecked()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

-- Font size row
local chanceFontRow = CreateFrame("Frame", nil, vsContent)
chanceFontRow:SetSize(FRAME_W - PAD * 2, 24)
chanceFontRow:SetPoint("TOPLEFT", chanceLabelCheck, "BOTTOMLEFT", 0, -10)

local chanceFontLbl = chanceFontRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
chanceFontLbl:SetPoint("LEFT", chanceFontRow, "LEFT", 0, 2)
chanceFontLbl:SetText("Font size:")
chanceFontLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local chanceFontBox = MakeFontSizeBox(chanceFontRow, "chanceFontSize")
chanceFontBox:SetPoint("LEFT", chanceFontLbl, "RIGHT", 8, 0)

local chanceFontHint = chanceFontRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
chanceFontHint:SetPoint("LEFT", chanceFontBox, "RIGHT", 6, 2)
chanceFontHint:SetText("(10–40)")
chanceFontHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Strata row
local chanceStrataRow, chanceStrataBtn = MakeStrataRow(vsContent, chanceFontRow, -6, "Strata:", "chanceStrata")

-- ─────────────────────────────────────────────────────────────
--  SECTION: Deck count
-- ─────────────────────────────────────────────────────────────

local deckHdr, deckRule = MakeSectionHeader(vsContent, chanceStrataRow, -18, "Deck Count")

local deckCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
deckCheck:SetPoint("TOPLEFT", deckRule, "BOTTOMLEFT", 0, -10)
deckCheck.text:SetText("Show deck count")
deckCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
deckCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showDeck = self:GetChecked()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

local deckLabelCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
deckLabelCheck:SetPoint("TOPLEFT", deckCheck, "BOTTOMLEFT", 0, -4)
deckLabelCheck.text:SetText("Show \"Deck:\" label text")
deckLabelCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
deckLabelCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showDeckLabel = self:GetChecked()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

-- Font size row
local deckFontRow = CreateFrame("Frame", nil, vsContent)
deckFontRow:SetSize(FRAME_W - PAD * 2, 24)
deckFontRow:SetPoint("TOPLEFT", deckLabelCheck, "BOTTOMLEFT", 0, -10)

local deckFontLbl = deckFontRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
deckFontLbl:SetPoint("LEFT", deckFontRow, "LEFT", 0, 2)
deckFontLbl:SetText("Font size:")
deckFontLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local deckFontBox = MakeFontSizeBox(deckFontRow, "deckFontSize")
deckFontBox:SetPoint("LEFT", deckFontLbl, "RIGHT", 8, 0)

local deckFontHint = deckFontRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
deckFontHint:SetPoint("LEFT", deckFontBox, "RIGHT", 6, 2)
deckFontHint:SetText("(10–40)")
deckFontHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Strata row
local deckStrataRow, deckStrataBtn = MakeStrataRow(vsContent, deckFontRow, -6, "Strata:", "deckStrata")

-- ─────────────────────────────────────────────────────────────
--  SECTION: Deck of cards
-- ─────────────────────────────────────────────────────────────

local cardsHdr, cardsRule = MakeSectionHeader(vsContent, deckStrataRow, -18, "Deck of Cards")

local cardsCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
cardsCheck:SetPoint("TOPLEFT", cardsRule, "BOTTOMLEFT", 0, -10)
cardsCheck.text:SetText("Show deck cards")
cardsCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
cardsCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showCards = self:GetChecked()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

local cardsRotateCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
cardsRotateCheck:SetPoint("TOPLEFT", cardsCheck, "BOTTOMLEFT", 0, -4)
cardsRotateCheck.text:SetText("Stack cards vertically")
cardsRotateCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
cardsRotateCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.cardsRotated = self:GetChecked()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

-- Card size slider
local cardsSizeRow = CreateFrame("Frame", nil, vsContent)
cardsSizeRow:SetSize(FRAME_W - PAD * 2, 36)
cardsSizeRow:SetPoint("TOPLEFT", cardsRotateCheck, "BOTTOMLEFT", 0, -10)

local cardsSizeLbl = cardsSizeRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
cardsSizeLbl:SetPoint("TOPLEFT", cardsSizeRow, "TOPLEFT", 0, -2)
cardsSizeLbl:SetText("Card size:")
cardsSizeLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local cardsSizeSlider = CreateFrame("Slider", nil, cardsSizeRow, "OptionsSliderTemplate")
cardsSizeSlider:SetPoint("TOPLEFT", cardsSizeLbl, "BOTTOMLEFT", -4, -6)
cardsSizeSlider:SetSize(200, 20)
cardsSizeSlider:SetMinMaxValues(8, 48)
cardsSizeSlider:SetValueStep(1)
cardsSizeSlider:SetObeyStepOnDrag(true)
cardsSizeSlider.Text:SetText("Card Size")
cardsSizeSlider.Low:SetText("8")
cardsSizeSlider.High:SetText("48")
cardsSizeSlider:SetScript("OnValueChanged", function(self, value)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.cardsSize = value
    self.Text:SetText("Card Size: " .. tostring(value))
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)

-- Strata row
local cardsStrataRow, cardsStrataBtn = MakeStrataRow(vsContent, cardsSizeRow, -10, "Strata:", "cardsStrata")

-- ─────────────────────────────────────────────────────────────
--  SECTION: Position
-- ─────────────────────────────────────────────────────────────

local posHdrText, posRule = MakeSectionHeader(vsContent, cardsStrataRow, -18, "Position")

local vsLocked  = true
local vsLockBtn = CreateFrame("Button", nil, vsContent, "UIPanelButtonTemplate")
vsLockBtn:SetSize(120, 24)
vsLockBtn:SetPoint("TOPLEFT", posRule, "BOTTOMLEFT", 0, -10)
vsLockBtn:SetText("Unlock to Move")
vsLockBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled) then
        PWT:Print("Enable the Void Shield tracker first.")
        return
    end
    vsLocked = not vsLocked
    if PWT.VoidShieldDeck then
        PWT.VoidShieldDeck:ShowWidget()
        PWT.VoidShieldDeck:SetMovable(not vsLocked)
    end
    if not vsLocked then
        vsLockBtn:SetText("Lock Position")
        vsLockBtn:GetFontString():SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
    else
        vsLockBtn:SetText("Unlock to Move")
        vsLockBtn:GetFontString():SetTextColor(1, 1, 1)
    end
end)

local vsResetBtn = CreateFrame("Button", nil, vsContent, "UIPanelButtonTemplate")
vsResetBtn:SetSize(110, 24)
vsResetBtn:SetPoint("LEFT", vsLockBtn, "RIGHT", 8, 0)
vsResetBtn:SetText("Reset Positions")
vsResetBtn:SetScript("OnClick", function()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:ResetPosition() end
    PWT:Print("Void Shield tracker position reset.")
end)

local posDesc = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
posDesc:SetPoint("TOPLEFT", vsLockBtn, "BOTTOMLEFT", 0, -4)
posDesc:SetWidth(FRAME_W - PAD * 2)
posDesc:SetJustifyH("LEFT")
posDesc:SetText("Unlock the tracker to drag it anywhere on screen, then lock to save the position.")
posDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local posHint = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
posHint:SetPoint("TOPLEFT", posDesc, "BOTTOMLEFT", 0, -8)
posHint:SetWidth(FRAME_W - PAD * 2)
posHint:SetJustifyH("LEFT")
posHint:SetText("The deck resets when a raid boss pull starts or when a Mythic+ key is activated. It does not reset between individual bosses in a Mythic+ dungeon.")
posHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ─────────────────────────────────────────────────────────────
--  SECTION: Proc Icon Alert
-- ─────────────────────────────────────────────────────────────

local procIconHdr, procIconRule = MakeSectionHeader(vsContent, posHint, -18, "Proc Icon Alert")

local procAlertCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
procAlertCheck:SetPoint("TOPLEFT", procIconRule, "BOTTOMLEFT", 0, -10)
procAlertCheck.text:SetText("Show Void Shield icon when proc fires")
procAlertCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
procAlertCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.procAlertEnabled = self:GetChecked()
end)

-- Alert size slider
local procAlertSizeRow = CreateFrame("Frame", nil, vsContent)
procAlertSizeRow:SetSize(FRAME_W - PAD * 2, 42)
procAlertSizeRow:SetPoint("TOPLEFT", procAlertCheck, "BOTTOMLEFT", 0, -10)

local procAlertSizeLbl = procAlertSizeRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
procAlertSizeLbl:SetPoint("TOPLEFT", procAlertSizeRow, "TOPLEFT", 0, -2)
procAlertSizeLbl:SetText("Alert size:")
procAlertSizeLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procAlertSizeSlider = CreateFrame("Slider", nil, procAlertSizeRow, "OptionsSliderTemplate")
procAlertSizeSlider:SetPoint("TOPLEFT", procAlertSizeLbl, "BOTTOMLEFT", -4, -6)
procAlertSizeSlider:SetSize(200, 20)
procAlertSizeSlider:SetMinMaxValues(16, 256)
procAlertSizeSlider:SetValueStep(2)
procAlertSizeSlider:SetObeyStepOnDrag(true)
procAlertSizeSlider.Text:SetText("Size")
procAlertSizeSlider.Low:SetText("16")
procAlertSizeSlider.High:SetText("256")
procAlertSizeSlider:SetScript("OnValueChanged", function(self, value)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.procAlertSize = value
    self.Text:SetText("Size: " .. tostring(value))
    -- Live-update if the widget exists
    if PWT.VoidShieldDeck and PWT.VoidShieldDeck.procAlertWidget then
        PWT.VoidShieldDeck.procAlertWidget:SetSize(value, value)
    end
end)

-- Strata row
local procAlertStrataRow, procAlertStrataBtn = MakeStrataRow(
    vsContent, procAlertSizeRow, -10, "Strata:", "procAlertStrata")
-- Override the MakeStrataRow OnClick callback so it also updates procAlertWidget directly.
-- (MakeStrataRow already calls VSD:ApplyStrata() which covers the deck widgets;
--  for the proc alert frame we update it here via a separate hook.)

-- Position buttons
local procAlertPosRow = CreateFrame("Frame", nil, vsContent)
procAlertPosRow:SetSize(FRAME_W - PAD * 2, 24)
procAlertPosRow:SetPoint("TOPLEFT", procAlertStrataRow, "BOTTOMLEFT", 0, -10)

local procAlertLocked = true
local procAlertLockBtn = CreateFrame("Button", nil, procAlertPosRow, "UIPanelButtonTemplate")
procAlertLockBtn:SetSize(120, 24)
procAlertLockBtn:SetPoint("LEFT", procAlertPosRow, "LEFT", 0, 0)
procAlertLockBtn:SetText("Unlock to Move")
procAlertLockBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled) then
        PWT:Print("Enable the Void Shield tracker first.")
        return
    end
    procAlertLocked = not procAlertLocked
    if PWT.VoidShieldDeck then
        PWT.VoidShieldDeck:SetProcAlertMovable(not procAlertLocked)
        if not procAlertLocked then
            PWT.VoidShieldDeck:ShowProcAlertPreview()
        else
            PWT.VoidShieldDeck:HideProcAlertPreview()
        end
    end
    if not procAlertLocked then
        procAlertLockBtn:SetText("Lock Position")
        procAlertLockBtn:GetFontString():SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
    else
        procAlertLockBtn:SetText("Unlock to Move")
        procAlertLockBtn:GetFontString():SetTextColor(1, 1, 1)
    end
end)

local procAlertResetBtn = CreateFrame("Button", nil, procAlertPosRow, "UIPanelButtonTemplate")
procAlertResetBtn:SetSize(110, 24)
procAlertResetBtn:SetPoint("LEFT", procAlertLockBtn, "RIGHT", 8, 0)
procAlertResetBtn:SetText("Reset Position")
procAlertResetBtn:SetScript("OnClick", function()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:ResetProcAlertPosition() end
    PWT:Print("Proc alert position reset.")
end)

-- ─────────────────────────────────────────────────────────────
--  SECTION: Proc Sound Alert
-- ─────────────────────────────────────────────────────────────

local procSoundHdr, procSoundRule = MakeSectionHeader(vsContent, procAlertPosRow, -18, "Proc Sound Alert")

local procSoundCheck = CreateFrame("CheckButton", nil, vsContent, "UICheckButtonTemplate")
procSoundCheck:SetPoint("TOPLEFT", procSoundRule, "BOTTOMLEFT", 0, -10)
procSoundCheck.text:SetText("Enable sound alert on proc")
procSoundCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
procSoundCheck:SetScript("OnClick", function(self)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.procSoundEnabled = self:GetChecked()
end)

-- Sound picker row
local procSoundPickRow = CreateFrame("Frame", nil, vsContent)
procSoundPickRow:SetSize(FRAME_W - PAD * 2, 24)
procSoundPickRow:SetPoint("TOPLEFT", procSoundCheck, "BOTTOMLEFT", 0, -10)

local procSoundLbl = procSoundPickRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
procSoundLbl:SetPoint("LEFT", procSoundPickRow, "LEFT", 0, 2)
procSoundLbl:SetText("Sound:")
procSoundLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procSoundDropBtn = CreateFrame("Button", nil, procSoundPickRow, "UIPanelButtonTemplate")
procSoundDropBtn:SetSize(180, 22)
procSoundDropBtn:SetPoint("LEFT", procSoundLbl, "RIGHT", 8, 0)
procSoundDropBtn:GetFontString():SetText("Alarm Clock")

local procSoundPreviewBtn = CreateFrame("Button", nil, procSoundPickRow, "UIPanelButtonTemplate")
procSoundPreviewBtn:SetSize(60, 22)
procSoundPreviewBtn:SetPoint("LEFT", procSoundDropBtn, "RIGHT", 6, 0)
procSoundPreviewBtn:SetText("Preview")
procSoundPreviewBtn:SetScript("OnClick", function()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:PlayProcSound() end
end)

-- ── Sound dropdown popup ──────────────────────────────────────
local VSD_SND_DROP_H = 200
local VSD_SND_ROW_H  = 20
local VSD_SND_DROP_W = 248
local VSD_SND_ROW_W  = VSD_SND_DROP_W - 30

local procSndDropPanel = CreateFrame("Frame", "PWT_VSD_SoundDropPanel", UIParent)
procSndDropPanel:SetSize(VSD_SND_DROP_W, VSD_SND_DROP_H)
procSndDropPanel:SetFrameStrata("TOOLTIP")
procSndDropPanel:SetFrameLevel(100)
procSndDropPanel:Hide()
UI:MakeBg(procSndDropPanel, {0.06, 0.06, 0.08, 0.98})
do
    local function addLine(p1, rp)
        local t = procSndDropPanel:CreateTexture(nil, "OVERLAY")
        t:SetHeight(1); t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
        t:SetPoint(p1, procSndDropPanel, rp, 0, 0)
        t:SetPoint(p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT",
                   procSndDropPanel, p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
    end
    addLine("TOPLEFT", "TOPLEFT"); addLine("BOTTOMLEFT", "BOTTOMLEFT")
end

local procSndScroll = CreateFrame("ScrollFrame", nil, procSndDropPanel, "UIPanelScrollFrameTemplate")
procSndScroll:SetPoint("TOPLEFT",     procSndDropPanel, "TOPLEFT",     4, -4)
procSndScroll:SetPoint("BOTTOMRIGHT", procSndDropPanel, "BOTTOMRIGHT", -22, 4)

local procSndDropChild = CreateFrame("Frame", nil, procSndScroll)
procSndDropChild:SetWidth(VSD_SND_ROW_W)
procSndDropChild:SetHeight(1)
procSndScroll:SetScrollChild(procSndDropChild)

local procSndDropRows = {}

local function HideSndDropdown()
    procSndDropPanel:Hide()
end

local function UpdateSndDropLabel()
    local idx  = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundIndex) or 5
    local list = (PWT.VoidShieldDeck and PWT.VoidShieldDeck.soundList) or {}
    local entry = list[idx]
    local name  = entry and entry.label or "Alarm Clock"
    if #name > 26 then name = name:sub(1, 23) .. "..." end
    procSoundDropBtn:GetFontString():SetText(name)
end

local function PopulateSndDropdown()
    for _, r in ipairs(procSndDropRows) do r:Hide() end
    wipe(procSndDropRows)

    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:BuildSoundList() end
    local list       = (PWT.VoidShieldDeck and PWT.VoidShieldDeck.soundList) or {}
    local currentIdx = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundIndex) or 5

    for i, entry in ipairs(list) do
        local row = CreateFrame("Button", nil, procSndDropChild)
        row:SetSize(VSD_SND_ROW_W, VSD_SND_ROW_H)
        row:SetPoint("TOPLEFT", procSndDropChild, "TOPLEFT", 0, -(i - 1) * VSD_SND_ROW_H)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row); row.bg = rowBg

        local rowLbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        rowLbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
        rowLbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rowLbl:SetJustifyH("LEFT")
        rowLbl:SetText(entry.label)

        if i == currentIdx then
            rowBg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.8)
            rowLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        else
            rowBg:SetColorTexture(0, 0, 0, 0)
            rowLbl:SetTextColor(C.text[1], C.text[2], C.text[3])
        end

        row:SetScript("OnEnter", function(self)
            local cur = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundIndex) or 5
            if i ~= cur then self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6) end
        end)
        row:SetScript("OnLeave", function(self)
            local cur = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundIndex) or 5
            if i ~= cur then self.bg:SetColorTexture(0, 0, 0, 0) end
        end)
        row:SetScript("OnClick", function()
            if PWT.db and PWT.db.voidShieldDeck then
                PWT.db.voidShieldDeck.procSoundIndex = i
            end
            UpdateSndDropLabel()
            HideSndDropdown()
        end)

        row:Show()
        procSndDropRows[i] = row
    end

    local totalH = #list * VSD_SND_ROW_H
    procSndDropChild:SetHeight(math.max(totalH, 1))
    local scrollMax = math.max(0, totalH - VSD_SND_DROP_H + 8)
    local scrollTo  = math.max(0, math.min(scrollMax, (currentIdx - 1) * VSD_SND_ROW_H - VSD_SND_DROP_H / 2))
    procSndScroll:SetVerticalScroll(scrollTo)
end

local procSndWatcher = CreateFrame("Frame", nil, UIParent)
procSndWatcher:SetAllPoints(UIParent)
procSndWatcher:SetFrameStrata("DIALOG")
procSndWatcher:EnableMouse(false)
procSndWatcher:Hide()
procSndDropPanel:HookScript("OnShow", function()
    procSndWatcher:EnableMouse(true)
    procSndWatcher:Show()
    procSndWatcher:SetScript("OnMouseDown", function(self)
        HideSndDropdown()
        self:EnableMouse(false)
        self:Hide()
    end)
end)

procSoundDropBtn:SetScript("OnClick", function(self)
    if procSndDropPanel:IsShown() then HideSndDropdown(); return end
    PopulateSndDropdown()
    procSndDropPanel:ClearAllPoints()
    procSndDropPanel:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    procSndDropPanel:Show()
end)

-- Volume slider
local procVolRow = CreateFrame("Frame", nil, vsContent)
procVolRow:SetSize(FRAME_W - PAD * 2, 42)
procVolRow:SetPoint("TOPLEFT", procSoundPickRow, "BOTTOMLEFT", 0, -10)

local procVolLbl = procVolRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
procVolLbl:SetPoint("TOPLEFT", procVolRow, "TOPLEFT", 0, -2)
procVolLbl:SetText("Volume:")
procVolLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procVolSlider = CreateFrame("Slider", nil, procVolRow, "OptionsSliderTemplate")
procVolSlider:SetSize(200, 20)
procVolSlider:SetPoint("TOPLEFT", procVolLbl, "BOTTOMLEFT", -4, -6)
procVolSlider:SetMinMaxValues(0.0, 1.0)
procVolSlider:SetValueStep(0.05)
procVolSlider:SetObeyStepOnDrag(true)
procVolSlider.Low:SetText("0%")
procVolSlider.High:SetText("100%")
procVolSlider.Text:SetText("")
procVolSlider:SetScript("OnValueChanged", function(self, val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.procSoundVolume = val
    self.Text:SetText(string.format("%d%%", math.floor(val * 100 + 0.5)))
end)

-- Sound channel dropdown
local VSD_CHANNELS = {
    { label = "SFX (Default)", value = "SFX"      },
    { label = "Master",        value = "Master"    },
    { label = "Music",         value = "Music"     },
    { label = "Ambience",      value = "Ambience"  },
    { label = "Dialog",        value = "Dialog"    },
}

local procChanRow = CreateFrame("Frame", nil, vsContent)
procChanRow:SetSize(FRAME_W - PAD * 2, 24)
procChanRow:SetPoint("TOPLEFT", procVolRow, "BOTTOMLEFT", 0, -10)

local procChanLbl = procChanRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
procChanLbl:SetPoint("LEFT", procChanRow, "LEFT", 0, 2)
procChanLbl:SetText("Channel:")
procChanLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procChanBtn = CreateFrame("Button", nil, procChanRow, "UIPanelButtonTemplate")
procChanBtn:SetSize(160, 22)
procChanBtn:SetPoint("LEFT", procChanLbl, "RIGHT", 8, 0)
procChanBtn:GetFontString():SetText("SFX (Default)")

local VSD_CHAN_DROP_W = 180
local VSD_CHAN_ROW_H  = 20
local VSD_CHAN_DROP_H = #VSD_CHANNELS * VSD_CHAN_ROW_H + 8
local VSD_CHAN_ROW_W  = VSD_CHAN_DROP_W - 30

local procChanPopup = CreateFrame("Frame", "PWT_VSD_ChanDropPanel", UIParent)
procChanPopup:SetSize(VSD_CHAN_DROP_W, VSD_CHAN_DROP_H)
procChanPopup:SetFrameStrata("TOOLTIP")
procChanPopup:SetFrameLevel(100)
procChanPopup:Hide()
UI:MakeBg(procChanPopup, {0.06, 0.06, 0.08, 0.98})
do
    local function addLine(p1, rp)
        local t = procChanPopup:CreateTexture(nil, "OVERLAY")
        t:SetHeight(1); t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
        t:SetPoint(p1, procChanPopup, rp, 0, 0)
        t:SetPoint(p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT",
                   procChanPopup, p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
    end
    addLine("TOPLEFT", "TOPLEFT"); addLine("BOTTOMLEFT", "BOTTOMLEFT")
end

local procChanScroll = CreateFrame("ScrollFrame", nil, procChanPopup, "UIPanelScrollFrameTemplate")
procChanScroll:SetPoint("TOPLEFT",     procChanPopup, "TOPLEFT",     4, -4)
procChanScroll:SetPoint("BOTTOMRIGHT", procChanPopup, "BOTTOMRIGHT", -22, 4)
local procChanChild = CreateFrame("Frame", nil, procChanScroll)
procChanChild:SetWidth(VSD_CHAN_ROW_W)
procChanChild:SetHeight(#VSD_CHANNELS * VSD_CHAN_ROW_H)
procChanScroll:SetScrollChild(procChanChild)
local procChanPopupRows = {}

local function GetChanLabel(value)
    for _, e in ipairs(VSD_CHANNELS) do if e.value == value then return e.label end end
    return "SFX (Default)"
end

local function HideChanPopup() procChanPopup:Hide() end

local function PopulateChanPopup()
    for _, r in ipairs(procChanPopupRows) do r:Hide() end
    wipe(procChanPopupRows)
    local curVal = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundChannel) or "SFX"
    for i, entry in ipairs(VSD_CHANNELS) do
        local row = CreateFrame("Button", nil, procChanChild)
        row:SetSize(VSD_CHAN_ROW_W, VSD_CHAN_ROW_H)
        row:SetPoint("TOPLEFT", procChanChild, "TOPLEFT", 0, -(i - 1) * VSD_CHAN_ROW_H)
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row); row.bg = rowBg
        local rowLbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        rowLbl:SetPoint("LEFT", row, "LEFT", 6, 0); rowLbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rowLbl:SetJustifyH("LEFT"); rowLbl:SetText(entry.label)
        local isSel = (entry.value == curVal)
        rowBg:SetColorTexture(isSel and C.tabActive[1] or 0, isSel and C.tabActive[2] or 0,
                              isSel and C.tabActive[3] or 0, isSel and C.tabActive[4] or 0)
        rowLbl:SetTextColor(isSel and C.textAccent[1] or C.text[1],
                            isSel and C.textAccent[2] or C.text[2],
                            isSel and C.textAccent[3] or C.text[3])
        row:SetScript("OnEnter", function(self)
            local cur = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundChannel) or "SFX"
            if entry.value ~= cur then self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6) end
        end)
        row:SetScript("OnLeave", function(self)
            local cur = (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundChannel) or "SFX"
            local active = (entry.value == cur)
            self.bg:SetColorTexture(active and C.tabActive[1] or 0, active and C.tabActive[2] or 0,
                                    active and C.tabActive[3] or 0, active and C.tabActive[4] or 0)
        end)
        row:SetScript("OnClick", function()
            if PWT.db and PWT.db.voidShieldDeck then PWT.db.voidShieldDeck.procSoundChannel = entry.value end
            procChanBtn:GetFontString():SetText(entry.label)
            HideChanPopup()
        end)
        row:Show(); procChanPopupRows[i] = row
    end
end

local procChanWatcher = CreateFrame("Frame", nil, UIParent)
procChanWatcher:SetAllPoints(UIParent); procChanWatcher:SetFrameStrata("DIALOG")
procChanWatcher:EnableMouse(false); procChanWatcher:Hide()
procChanPopup:HookScript("OnShow", function()
    procChanWatcher:EnableMouse(true); procChanWatcher:Show()
    procChanWatcher:SetScript("OnMouseDown", function(self)
        HideChanPopup(); self:EnableMouse(false); self:Hide()
    end)
end)

procChanBtn:SetScript("OnClick", function(self)
    if procChanPopup:IsShown() then HideChanPopup(); return end
    PopulateChanPopup()
    procChanPopup:ClearAllPoints()
    procChanPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    procChanPopup:Show()
end)

-- ── Sync ──────────────────────────────────────────────────────

function UI:SyncVoidShield()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck
    chanceCheck:SetChecked(cfg.showChance ~= false)
    chanceLabelCheck:SetChecked(cfg.showChanceLabel ~= false)
    deckCheck:SetChecked(cfg.showDeck ~= false)
    deckLabelCheck:SetChecked(cfg.showDeckLabel ~= false)
    cardsCheck:SetChecked(cfg.showCards ~= false)
    cardsRotateCheck:SetChecked(cfg.cardsRotated == true)
    chanceFontBox:SetText(tostring(cfg.chanceFontSize or 18))
    deckFontBox:SetText(tostring(cfg.deckFontSize or 18))
    cardsSizeSlider:SetValue(cfg.cardsSize or 18)
    cardsSizeSlider.Text:SetText("Card Size: " .. tostring(cfg.cardsSize or 18))
    chanceStrataBtn:GetFontString():SetText(cfg.chanceStrata or "MEDIUM")
    deckStrataBtn:GetFontString():SetText(cfg.deckStrata   or "MEDIUM")
    cardsStrataBtn:GetFontString():SetText(cfg.cardsStrata  or "MEDIUM")
    -- Deck tracker lock state
    vsLockBtn:SetText(vsLocked and "Unlock to Move" or "Lock Position")
    vsLockBtn:GetFontString():SetTextColor(
        vsLocked and 1 or C.textAccent[1],
        vsLocked and 1 or C.textAccent[2],
        vsLocked and 1 or C.textAccent[3])
    -- Proc icon alert
    procAlertCheck:SetChecked(cfg.procAlertEnabled == true)
    procAlertSizeSlider:SetValue(cfg.procAlertSize or 64)
    procAlertSizeSlider.Text:SetText("Size: " .. tostring(cfg.procAlertSize or 64))
    procAlertStrataBtn:GetFontString():SetText(cfg.procAlertStrata or "HIGH")
    procAlertLockBtn:SetText(procAlertLocked and "Unlock to Move" or "Lock Position")
    procAlertLockBtn:GetFontString():SetTextColor(
        procAlertLocked and 1 or C.textAccent[1],
        procAlertLocked and 1 or C.textAccent[2],
        procAlertLocked and 1 or C.textAccent[3])
    -- Proc sound alert
    procSoundCheck:SetChecked(cfg.procSoundEnabled == true)
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:BuildSoundList() end
    UpdateSndDropLabel()
    procVolSlider:SetValue(cfg.procSoundVolume or 1.0)
    procVolSlider.Text:SetText(string.format("%d%%", math.floor((cfg.procSoundVolume or 1.0) * 100 + 0.5)))
    procChanBtn:GetFontString():SetText(GetChanLabel(cfg.procSoundChannel or "SFX"))
end
