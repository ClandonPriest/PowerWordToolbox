-- ============================================================
--  Power Word: Toolbox  |  Options/Atonement_Options.lua
--  Atonement tracker options tab: enable widget, show lowest
--  timer, lock position, font sizes, reset position.
-- ============================================================

local _, PWT = ...
local UI  = PWT.UI
local AT  = PWT.Atonement
local C   = UI.C
local PAD    = UI.PAD
local FRAME_W = UI.FRAME_W

-- ── Atonement Options Tab ─────────────────────────────────────

local atPanel = UI:AddTab("atonement", "Atonement", 3)

local atOptTitle = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
atOptTitle:SetPoint("TOPLEFT", atPanel, "TOPLEFT", PAD, -PAD)
atOptTitle:SetText("Atonement Tracker")
atOptTitle:SetTextColor(C.text[1], C.text[2], C.text[3])

local atOptSub = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atOptSub:SetPoint("TOPLEFT", atOptTitle, "BOTTOMLEFT", 0, -4)
atOptSub:SetText("Displays active Atonement count and lowest timer as a moveable widget.")
atOptSub:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atOptLine = UI:MakeLine(atPanel, C.border, 1)
atOptLine:SetPoint("TOPLEFT",  atOptSub, "BOTTOMLEFT",  0, -8)
atOptLine:SetPoint("TOPRIGHT", atPanel, "TOPRIGHT",  -PAD, -8)

-- Show lowest timer checkbox
local atLowestCheck = CreateFrame("CheckButton", nil, atPanel, "UICheckButtonTemplate")
atLowestCheck:SetPoint("TOPLEFT", atOptLine, "BOTTOMLEFT", 0, -10)
atLowestCheck.text:SetText("Show lowest Atonement timer")
atLowestCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
atLowestCheck:SetScript("OnClick", function(self)
    PWT.db.atonement.showLowest = self:GetChecked()
    PWT.Atonement:UpdateWidget()
end)

local atLowestDesc = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atLowestDesc:SetPoint("TOPLEFT", atLowestCheck, "BOTTOMLEFT", 26, -2)
atLowestDesc:SetWidth(FRAME_W - PAD * 2 - 30)
atLowestDesc:SetJustifyH("LEFT")
atLowestDesc:SetText("Timer turns yellow below 6s and red below 3s.")
atLowestDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Lock widget checkbox
local atLockCheck = CreateFrame("CheckButton", nil, atPanel, "UICheckButtonTemplate")
atLockCheck:SetPoint("TOPLEFT", atLowestDesc, "BOTTOMLEFT", -26, -8)
atLockCheck.text:SetText("Lock widget position and size")
atLockCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
atLockCheck:SetScript("OnClick", function(self)
    PWT.db.atonement.locked = self:GetChecked()
    PWT.Atonement:UpdateWidget()
end)

local atLockDesc = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atLockDesc:SetPoint("TOPLEFT", atLockCheck, "BOTTOMLEFT", 26, -2)
atLockDesc:SetWidth(FRAME_W - PAD * 2 - 30)
atLockDesc:SetJustifyH("LEFT")
atLockDesc:SetText("Hides the background and disables moving/resizing. Unlock to reposition.")
atLockDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Mouse follow checkbox
local atMouseCheck = CreateFrame("CheckButton", nil, atPanel, "UICheckButtonTemplate")
atMouseCheck:SetPoint("TOPLEFT", atLockDesc, "BOTTOMLEFT", -26, -8)
atMouseCheck.text:SetText("Follow mouse cursor")
atMouseCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])

local atMouseDesc = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atMouseDesc:SetPoint("TOPLEFT", atMouseCheck, "BOTTOMLEFT", 26, -2)
atMouseDesc:SetWidth(FRAME_W - PAD * 2 - 30)
atMouseDesc:SetJustifyH("LEFT")
atMouseDesc:SetText("Widget position follows your mouse cursor. Lock position is disabled while active.")
atMouseDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Anchor point label (only shown when mouseFollow is on)
local atAnchorLabel = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atAnchorLabel:SetPoint("TOPLEFT", atMouseDesc, "BOTTOMLEFT", 0, -8)
atAnchorLabel:SetText("Widget corner at cursor:")
atAnchorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- 2×2 anchor toggle buttons
local ANCHOR_OPTS = {
    { label = "Top Left",     key = "TOPLEFT",     col = 0, row = 0 },
    { label = "Top Right",    key = "TOPRIGHT",    col = 1, row = 0 },
    { label = "Bottom Left",  key = "BOTTOMLEFT",  col = 0, row = 1 },
    { label = "Bottom Right", key = "BOTTOMRIGHT", col = 1, row = 1 },
}
local ANCHOR_BTN_W, ANCHOR_BTN_H, ANCHOR_BTN_GAP = 106, 22, 6
local anchorBtns = {}

for i, opt in ipairs(ANCHOR_OPTS) do
    local btn = CreateFrame("Button", nil, atPanel)
    btn:SetSize(ANCHOR_BTN_W, ANCHOR_BTN_H)
    btn:SetPoint("TOPLEFT", atAnchorLabel, "BOTTOMLEFT",
        opt.col * (ANCHOR_BTN_W + ANCHOR_BTN_GAP),
        -(8 + opt.row * (ANCHOR_BTN_H + 4)))

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints(btn)
    btnBg:SetColorTexture(0.10, 0.10, 0.12, 0.85)
    btn.bg = btnBg

    local btnLbl = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    btnLbl:SetAllPoints(btn)
    btnLbl:SetJustifyH("CENTER")
    btnLbl:SetText(opt.label)
    btnLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    btn.lbl = btnLbl

    btn:SetScript("OnClick", function()
        PWT.db.atonement.mouseAnchor = opt.key
        -- Refresh button highlight states
        for _, b in ipairs(anchorBtns) do
            local active = (PWT.db.atonement.mouseAnchor == ANCHOR_OPTS[b.optIndex].key)
            b.bg:SetColorTexture(
                active and C.tabActive[1] or 0.10,
                active and C.tabActive[2] or 0.10,
                active and C.tabActive[3] or 0.12,
                active and C.tabActive[4] or 0.85)
            b.lbl:SetTextColor(
                active and C.textAccent[1] or C.textMuted[1],
                active and C.textAccent[2] or C.textMuted[2],
                active and C.textAccent[3] or C.textMuted[3])
        end
    end)
    btn:SetScript("OnEnter", function(self)
        if PWT.db.atonement.mouseAnchor ~= opt.key then
            self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.8)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local active = (PWT.db.atonement.mouseAnchor == opt.key)
        self.bg:SetColorTexture(
            active and C.tabActive[1] or 0.10,
            active and C.tabActive[2] or 0.10,
            active and C.tabActive[3] or 0.12,
            active and C.tabActive[4] or 0.85)
    end)
    btn.optIndex = i
    anchorBtns[i] = btn
end

-- Placeholder frame so atOptLine2 has a stable anchor below the 2-row grid
local atAnchorSpacer = CreateFrame("Frame", nil, atPanel)
atAnchorSpacer:SetHeight(ANCHOR_BTN_H * 2 + 4)
atAnchorSpacer:SetPoint("TOPLEFT",  atAnchorLabel, "BOTTOMLEFT",  0, -8)
atAnchorSpacer:SetPoint("TOPRIGHT", atPanel,       "TOPRIGHT",    -PAD, 0)

-- Helper: sync lock check enabled state based on mouseFollow
local function UpdateAtLockState()
    local following = PWT.db and PWT.db.atonement.mouseFollow
    atLockCheck:SetEnabled(not following)
    if following then
        atLockCheck.text:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    else
        atLockCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    atAnchorLabel:SetShown(following)
    for _, btn in ipairs(anchorBtns) do btn:SetShown(following) end
end

atMouseCheck:SetScript("OnClick", function(self)
    PWT.db.atonement.mouseFollow = self:GetChecked()
    if not self:GetChecked() then
        -- UpdateWidget's position-save block would capture the cursor location
        -- (widget is still there from the last OnUpdate frame). Skip it so
        -- posX/posY retains the position from before mouseFollow was enabled.
        PWT.Atonement.skipNextPositionSave = true
    end
    UpdateAtLockState()
    PWT.Atonement:UpdateWidget()
end)

local atOptLine2 = UI:MakeLine(atPanel, C.border, 1)
atOptLine2:SetPoint("TOPLEFT",  atAnchorSpacer, "BOTTOMLEFT",  0, -12)
atOptLine2:SetPoint("TOPRIGHT", atPanel, "TOPRIGHT",  -PAD, -12)

-- Font size controls
local atFontHeader = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
atFontHeader:SetPoint("TOPLEFT", atOptLine2, "BOTTOMLEFT", 0, -10)
atFontHeader:SetText("Text Size")
atFontHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

-- Count font size
local atCountSizeLabel = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atCountSizeLabel:SetPoint("TOPLEFT", atFontHeader, "BOTTOMLEFT", 0, -8)
atCountSizeLabel:SetText("Count:")
atCountSizeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atCountSizeBox = CreateFrame("EditBox", nil, atPanel, "InputBoxTemplate")
atCountSizeBox:SetSize(50, 22)
atCountSizeBox:SetPoint("LEFT", atCountSizeLabel, "RIGHT", 8, 0)
atCountSizeBox:SetAutoFocus(false)
atCountSizeBox:SetMaxLetters(3)
atCountSizeBox:SetNumeric(true)
atCountSizeBox:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then
        PWT.db.atonement.countFontSize = math.max(8, math.min(72, v))
        self:SetText(tostring(PWT.db.atonement.countFontSize))
        PWT.Atonement:UpdateWidget()
    end
    self:ClearFocus()
end)
atCountSizeBox:SetScript("OnEditFocusLost", function(self)
    local v = tonumber(self:GetText())
    if v then
        PWT.db.atonement.countFontSize = math.max(8, math.min(72, v))
        self:SetText(tostring(PWT.db.atonement.countFontSize))
        PWT.Atonement:UpdateWidget()
    end
end)

local atCountSizeHint = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atCountSizeHint:SetPoint("LEFT", atCountSizeBox, "RIGHT", 6, 0)
atCountSizeHint:SetText("px  (8–72)")
atCountSizeHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Timer font size
local atTimerSizeLabel = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atTimerSizeLabel:SetPoint("TOPLEFT", atCountSizeLabel, "BOTTOMLEFT", 0, -8)
atTimerSizeLabel:SetText("Timer: ")
atTimerSizeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atTimerSizeBox = CreateFrame("EditBox", nil, atPanel, "InputBoxTemplate")
atTimerSizeBox:SetSize(50, 22)
atTimerSizeBox:SetPoint("LEFT", atTimerSizeLabel, "RIGHT", 8, 0)
atTimerSizeBox:SetAutoFocus(false)
atTimerSizeBox:SetMaxLetters(3)
atTimerSizeBox:SetNumeric(true)
atTimerSizeBox:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then
        PWT.db.atonement.timerFontSize = math.max(8, math.min(72, v))
        self:SetText(tostring(PWT.db.atonement.timerFontSize))
        PWT.Atonement:UpdateWidget()
    end
    self:ClearFocus()
end)
atTimerSizeBox:SetScript("OnEditFocusLost", function(self)
    local v = tonumber(self:GetText())
    if v then
        PWT.db.atonement.timerFontSize = math.max(8, math.min(72, v))
        self:SetText(tostring(PWT.db.atonement.timerFontSize))
        PWT.Atonement:UpdateWidget()
    end
end)

local atTimerSizeHint = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atTimerSizeHint:SetPoint("LEFT", atTimerSizeBox, "RIGHT", 6, 0)
atTimerSizeHint:SetText("px  (8–72)")
atTimerSizeHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atOptLine3 = UI:MakeLine(atPanel, C.border, 1)
atOptLine3:SetPoint("TOPLEFT",  atTimerSizeLabel, "BOTTOMLEFT",  0, -12)
atOptLine3:SetPoint("TOPRIGHT", atPanel, "TOPRIGHT",  -PAD, -12)

local atMoveHint = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atMoveHint:SetPoint("TOPLEFT", atOptLine3, "BOTTOMLEFT", 0, -10)
atMoveHint:SetWidth(FRAME_W - PAD * 2)
atMoveHint:SetJustifyH("LEFT")
atMoveHint:SetText("|cffcc99ffMoving:|r  Drag the widget (unlock first)")
atMoveHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Reset position button
local atResetBtn = CreateFrame("Button", nil, atPanel, "UIPanelButtonTemplate")
atResetBtn:SetSize(130, 26)
atResetBtn:SetPoint("TOPLEFT", atMoveHint, "BOTTOMLEFT", 0, -10)
atResetBtn:SetText("Reset Position")
atResetBtn:SetScript("OnClick", function()
    PWT.db.atonement.posX = nil
    PWT.db.atonement.posY = nil
    PWT.Atonement:UpdateWidget()
    PWT:Print("Atonement widget position reset.")
end)

-- Called by UI:SwitchTab when Atonement tab becomes active
function UI:SyncAtonement()
    if not PWT.db then return end
    atLowestCheck:SetChecked(PWT.db.atonement.showLowest)
    atLockCheck:SetChecked(PWT.db.atonement.locked)
    atCountSizeBox:SetText(tostring(PWT.db.atonement.countFontSize or 32))
    atTimerSizeBox:SetText(tostring(PWT.db.atonement.timerFontSize or 20))
    atMouseCheck:SetChecked(PWT.db.atonement.mouseFollow)
    -- Sync anchor button highlight states
    local currentAnchor = PWT.db.atonement.mouseAnchor or "TOPLEFT"
    for _, btn in ipairs(anchorBtns) do
        local active = (ANCHOR_OPTS[btn.optIndex].key == currentAnchor)
        btn.bg:SetColorTexture(
            active and C.tabActive[1] or 0.10,
            active and C.tabActive[2] or 0.10,
            active and C.tabActive[3] or 0.12,
            active and C.tabActive[4] or 0.85)
        btn.lbl:SetTextColor(
            active and C.textAccent[1] or C.textMuted[1],
            active and C.textAccent[2] or C.textMuted[2],
            active and C.textAccent[3] or C.textMuted[3])
    end
    UpdateAtLockState()
end

-- Module capability flags — set on login and spec change
PWT.isPriest  = false
PWT.isDisc    = false