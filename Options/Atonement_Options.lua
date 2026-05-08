-- Power Word: Toolbox | Options/Atonement_Options.lua

local _, PWT = ...
local UI      = PWT.UI
local C       = UI.C
local PAD     = UI.PAD
local CONTENT_W = UI.CONTENT_W

local atPanel = UI:AddTab("atonement", "Atonement", 3)

-- ── Display options ────────────────────────────────────────────────────────

-- Forward declarations: onChange closes over UpdateAtLockState by upvalue ref;
-- UpdateAtLockState is assigned after anchorBtns is built.
-- atOptLine2 and atLockRow forward-declared so closures can reference them.
local atMouseCheck
local UpdateAtLockState
local atOptLine2
local atLockRow

local atLowestCheck = UI:MakeCheckbox(atPanel, "Show lowest Atonement timer", nil, function(val)
    PWT.db.atonement.showLowest = val
    PWT.Atonement:UpdateWidget()
end)
atLowestCheck:SetPoint("TOPLEFT", atPanel, "TOPLEFT", 0, -PAD)
atLowestCheck:SetPoint("RIGHT", atPanel, "RIGHT", -PAD, 0)

local atLowestDesc = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atLowestDesc:SetPoint("TOPLEFT", atLowestCheck, "BOTTOMLEFT", 22, -2)
atLowestDesc:SetWidth(CONTENT_W - PAD * 2 - 26)
atLowestDesc:SetJustifyH("LEFT")
atLowestDesc:SetText("Timer turns yellow below 6s and red below 3s.")
atLowestDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Single creation of atMouseCheck with real onChange (forward-declared above).
atMouseCheck = UI:MakeCheckbox(atPanel, "Follow mouse cursor", nil, function(val)
    PWT.db.atonement.mouseFollow = val
    if not val then
        PWT.Atonement.skipNextPositionSave = true
    end
    UpdateAtLockState()
    PWT.Atonement:UpdateWidget()
end)
atMouseCheck:SetPoint("TOPLEFT", atLowestDesc, "BOTTOMLEFT", -22, -8)
atMouseCheck:SetPoint("RIGHT", atPanel, "RIGHT", -PAD, 0)

local atMouseDesc = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atMouseDesc:SetPoint("TOPLEFT", atMouseCheck, "BOTTOMLEFT", 22, -2)
atMouseDesc:SetWidth(CONTENT_W - PAD * 2 - 26)
atMouseDesc:SetJustifyH("LEFT")
atMouseDesc:SetText("Widget position follows your mouse cursor. Unlock/lock is disabled while active.")
atMouseDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atAnchorLabel = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atAnchorLabel:SetPoint("TOPLEFT", atMouseDesc, "BOTTOMLEFT", 0, -8)
atAnchorLabel:SetText("Widget corner at cursor:")
atAnchorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

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
        for _, b in ipairs(anchorBtns) do
            local active = (PWT.db.atonement.mouseAnchor == ANCHOR_OPTS[b.optIndex].key)
            UI:StyleButton(b, active)
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
        UI:StyleButton(self, active)
    end)
    btn.optIndex = i
    anchorBtns[i] = btn
end

local atAnchorSpacer = CreateFrame("Frame", nil, atPanel)
atAnchorSpacer:SetHeight(ANCHOR_BTN_H * 2 + 4)
atAnchorSpacer:SetPoint("TOPLEFT",  atAnchorLabel, "BOTTOMLEFT",  0, -8)
atAnchorSpacer:SetPoint("TOPRIGHT", atPanel,        "TOPRIGHT",   -PAD, 0)

-- Assigned after anchorBtns and atAnchorLabel are fully built.
-- Re-anchors atOptLine2 to skip the spacer when not following (removes gap),
-- offsets by -22 to land at x=0 (fixes tabbed-in alignment).
-- Also dims the lock button when mouseFollow is active.
UpdateAtLockState = function()
    local following = PWT.db and PWT.db.atonement.mouseFollow
    atAnchorLabel:SetShown(following)
    for _, btn in ipairs(anchorBtns) do btn:SetShown(following) end
    if atLockRow then
        atLockRow.lockBtn:SetAlpha(following and 0.4 or 1.0)
        atLockRow.lockBtn:EnableMouse(not following)
    end
    atOptLine2:ClearAllPoints()
    if following then
        atOptLine2:SetPoint("TOPLEFT",  atAnchorSpacer, "BOTTOMLEFT", -22, -12)
    else
        atOptLine2:SetPoint("TOPLEFT",  atMouseDesc,    "BOTTOMLEFT", -22, -12)
    end
    atOptLine2:SetPoint("TOPRIGHT", atPanel, "TOPRIGHT", -PAD, -12)
end

atOptLine2 = UI:MakeLine(atPanel, C.border, 1)

-- ── Text Size ─────────────────────────────────────────────────────────────

local textSizeHdr = UI:MakeSectionHeader(atPanel, atOptLine2, -8, "Text Size")

local atCountSizeLabel = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atCountSizeLabel:SetPoint("TOPLEFT", textSizeHdr, "BOTTOMLEFT", 0, -8)
atCountSizeLabel:SetText("Count:")
atCountSizeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atCountSizeBox = UI:MakeFontSizeBox(atPanel, 8, 72, function(v)
    PWT.db.atonement.countFontSize = v
    PWT.Atonement:UpdateWidget()
end)
atCountSizeBox:SetPoint("LEFT", atCountSizeLabel, "RIGHT", 8, 0)

local atCountSizeHint = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atCountSizeHint:SetPoint("LEFT", atCountSizeBox, "RIGHT", 6, 0)
atCountSizeHint:SetText("px  (8-72)")
atCountSizeHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atTimerSizeLabel = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atTimerSizeLabel:SetPoint("TOPLEFT", atCountSizeLabel, "BOTTOMLEFT", 0, -8)
atTimerSizeLabel:SetText("Timer:")
atTimerSizeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atTimerSizeBox = UI:MakeFontSizeBox(atPanel, 8, 72, function(v)
    PWT.db.atonement.timerFontSize = v
    PWT.Atonement:UpdateWidget()
end)
atTimerSizeBox:SetPoint("LEFT", atTimerSizeLabel, "RIGHT", 8, 0)

local atTimerSizeHint = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atTimerSizeHint:SetPoint("LEFT", atTimerSizeBox, "RIGHT", 6, 0)
atTimerSizeHint:SetText("px  (8-72)")
atTimerSizeHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local atOptLine3 = UI:MakeLine(atPanel, C.border, 1)
atOptLine3:SetPoint("TOPLEFT",  atTimerSizeLabel, "BOTTOMLEFT",  0, -12)
atOptLine3:SetPoint("TOPRIGHT", atPanel,           "TOPRIGHT", -PAD, -12)

-- ── Position ──────────────────────────────────────────────────────────────

atLockRow = UI:MakeLockResetRow(atPanel,
    function()  -- onLock
        if not (PWT.db and PWT.db.atonement) then return end
        PWT.db.atonement.locked = true
        PWT.Atonement:UpdateWidget()
    end,
    function()  -- onUnlock
        if PWT.db and PWT.db.atonement and PWT.db.atonement.mouseFollow then
            atLockRow.setLocked(true)
            return
        end
        if not (PWT.db and PWT.db.atonement and PWT.db.atonement.enabled) then
            PWT:Print("Enable the tracker first.")
            atLockRow.setLocked(true)
            return
        end
        PWT.db.atonement.locked = false
        PWT.Atonement:UpdateWidget()
    end,
    function()  -- onReset
        PWT.db.atonement.posX = nil
        PWT.db.atonement.posY = nil
        PWT.Atonement:UpdateWidget()
        PWT:Print("Atonement widget position reset.")
    end,
    "Unlock to Move", "Lock Position")
atLockRow:SetPoint("TOPLEFT", atOptLine3, "BOTTOMLEFT", 0, -10)
atLockRow:SetPoint("RIGHT",   atPanel,    "RIGHT",    -PAD, 0)

local atPosDesc = atPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
atPosDesc:SetPoint("TOPLEFT", atLockRow, "BOTTOMLEFT", 0, -4)
atPosDesc:SetWidth(CONTENT_W - PAD * 2)
atPosDesc:SetJustifyH("LEFT")
atPosDesc:SetText("Unlock the widget to drag it anywhere on screen, then lock to save the position.")
atPosDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ── Sync ──────────────────────────────────────────────────────────────────

function UI:SyncAtonement()
    if not PWT.db then return end
    atLowestCheck.set(PWT.db.atonement.showLowest)
    atMouseCheck.set(PWT.db.atonement.mouseFollow)
    atLockRow.setLocked(PWT.db.atonement.locked ~= false)
    atCountSizeBox:SetText(tostring(PWT.db.atonement.countFontSize or 32))
    atTimerSizeBox:SetText(tostring(PWT.db.atonement.timerFontSize or 20))
    local currentAnchor = PWT.db.atonement.mouseAnchor or "TOPLEFT"
    for _, btn in ipairs(anchorBtns) do
        local active = (ANCHOR_OPTS[btn.optIndex].key == currentAnchor)
        UI:StyleButton(btn, active)
        btn.lbl:SetTextColor(
            active and C.textAccent[1] or C.textMuted[1],
            active and C.textAccent[2] or C.textMuted[2],
            active and C.textAccent[3] or C.textMuted[3])
    end
    UpdateAtLockState()
end

PWT.isPriest = false
PWT.isDisc   = false
