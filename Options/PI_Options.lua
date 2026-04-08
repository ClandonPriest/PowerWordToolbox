-- ============================================================
--  Power Word: Toolbox  |  Options/PI_Options.lua
--  Power Infusion options tab: mode toggle, priority/sequence
--  list, alert settings (glow, sound).
-- ============================================================

local _, PWT = ...
local UI  = PWT.UI
local PI  = PWT.PI
local C   = UI.C
local PAD    = UI.PAD
local FRAME_W = UI.FRAME_W

-- NOTE: This file references PWT.PI (Modules/PI.lua) and PWT.RaidFrames
-- for all combat logic. This file is purely UI.

local piPanel = UI:AddTab("pi", "Power Infusion", 2)

-- 1) Title
local piTitle = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
piTitle:SetPoint("TOPLEFT", piPanel, "TOPLEFT", PAD, -PAD)
piTitle:SetText("Power Infusion")
piTitle:SetTextColor(C.text[1], C.text[2], C.text[3])

-- 2) Agnostic description
local piSub = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
piSub:SetPoint("TOPLEFT", piTitle, "BOTTOMLEFT", 0, -4)
piSub:SetText("Configure how Power Infusion targets are selected and alerted during combat.")
piSub:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local piTopLine = UI:MakeLine(piPanel, C.border, 1)
piTopLine:SetPoint("TOPLEFT",  piSub, "BOTTOMLEFT",  0, -8)
piTopLine:SetPoint("TOPRIGHT", piPanel, "TOPRIGHT",  -PAD, -8)

local RefreshList  -- forward declaration, defined after row pool is built

-- 3) Mode selector
local modeLabel = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modeLabel:SetPoint("TOPLEFT", piTopLine, "BOTTOMLEFT", 4, -10)
modeLabel:SetText("Mode:")
modeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local modePriorityBtn = CreateFrame("Button", "PWT_ModePriorityBtn", UI.optionsFrame)
UI.modePriorityBtn = modePriorityBtn
modePriorityBtn:SetSize(100, 22)
modePriorityBtn:SetPoint("LEFT", modeLabel, "RIGHT", 8, 0)
modePriorityBtn:SetFrameStrata("DIALOG")
modePriorityBtn:SetFrameLevel(100)
local modePriorityBg = modePriorityBtn:CreateTexture(nil, "BACKGROUND")
modePriorityBg:SetAllPoints(modePriorityBtn)
modePriorityBg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
local modePriorityLbl = modePriorityBtn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modePriorityLbl:SetAllPoints(modePriorityBtn)
modePriorityLbl:SetJustifyH("CENTER")
modePriorityLbl:SetText("Priority List")
modePriorityLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local modeSequenceBtn = CreateFrame("Button", "PWT_ModeSequenceBtn", UI.optionsFrame)
UI.modeSequenceBtn = modeSequenceBtn
modeSequenceBtn:SetSize(100, 22)
modeSequenceBtn:SetPoint("LEFT", modePriorityBtn, "RIGHT", 6, 0)
modeSequenceBtn:SetFrameStrata("DIALOG")
modeSequenceBtn:SetFrameLevel(100)
local modeSequenceBg = modeSequenceBtn:CreateTexture(nil, "BACKGROUND")
modeSequenceBg:SetAllPoints(modeSequenceBtn)
modeSequenceBg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
local modeSequenceLbl = modeSequenceBtn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modeSequenceLbl:SetAllPoints(modeSequenceBtn)
modeSequenceLbl:SetJustifyH("CENTER")
modeSequenceLbl:SetText("PI Sequence")
modeSequenceLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Sequence position indicator
local seqIndexLabel = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
UI.seqIndexLabel = seqIndexLabel
seqIndexLabel:SetPoint("LEFT", modeSequenceBtn, "RIGHT", 10, 0)
seqIndexLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
seqIndexLabel:Hide()

-- 5) Mode description (dynamic)
local modeDescLabel = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modeDescLabel:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", 0, -6)
modeDescLabel:SetWidth(FRAME_W - PAD * 2 - 20)
modeDescLabel:SetJustifyH("LEFT")
modeDescLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Forward-declared so UpdateModeButtons (defined below) can reference them.
-- Assigned after piEnableLine is created.
local stickLastCheck, stickLastDesc

local function UpdateSeqIndexLabel()
    if not PWT.db then return end
    local seq = PWT.db.piSequenceList
    local idx = PWT.PI and PWT.PI.sequenceIndex or 1
    if seq and #seq > 0 then
        seqIndexLabel:SetText("Next: " .. math.min(idx, #seq + 1) .. " / " .. #seq)
    else
        seqIndexLabel:SetText("Empty")
    end
end

local function UpdateModeButtons()
    local mode = PWT.db and PWT.db.piMode or "priority"
    if mode == "priority" then
        modePriorityBg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.9)
        modePriorityLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        modeSequenceBg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
        modeSequenceLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
        seqIndexLabel:Hide()
        stickLastCheck:Hide()
        stickLastDesc:Hide()
        modeDescLabel:SetText("On any combat whisper, highlight the first player from the list who is in your group.")
    else
        modeSequenceBg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.9)
        modeSequenceLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        modePriorityBg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
        modePriorityLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
        seqIndexLabel:Show()
        UpdateSeqIndexLabel()
        modeDescLabel:SetText("On each combat whisper, highlight the next player in the sequence. Resets on boss pull.")
        stickLastCheck:Show()
        stickLastDesc:Show()
    end
end

modePriorityBtn:SetScript("OnClick", function()
    PWT.db.piMode = "priority"
    UpdateModeButtons()
    RefreshList()
end)

modeSequenceBtn:SetScript("OnClick", function()
    PWT.db.piMode = "sequence"
    UpdateModeButtons()
    RefreshList()
end)

for _, info in ipairs({
    { btn=modePriorityBtn, bg=modePriorityBg, key="priority" },
    { btn=modeSequenceBtn, bg=modeSequenceBg, key="sequence" },
}) do
    info.btn:SetScript("OnEnter", function()
        if (PWT.db.piMode or "priority") ~= info.key then
            info.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.7)
        end
    end)
    info.btn:SetScript("OnLeave", function()
        if (PWT.db.piMode or "priority") ~= info.key then
            info.bg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
        end
    end)
end

modePriorityBtn:Hide()
modeSequenceBtn:Hide()

-- Stick-to-last toggle (sequence mode only)
stickLastCheck = CreateFrame("CheckButton", nil, piPanel, "UICheckButtonTemplate")
stickLastCheck:SetPoint("TOPLEFT", modeDescLabel, "BOTTOMLEFT", -2, -4)
stickLastCheck.text:SetText("Repeat last entry after sequence ends")
stickLastCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
stickLastCheck:SetScript("OnClick", function(self)
    PWT.db.piSequenceStickLast = self:GetChecked()
end)
stickLastCheck:Hide()

stickLastDesc = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
stickLastDesc:SetPoint("TOPLEFT", stickLastCheck, "BOTTOMLEFT", 26, -2)
stickLastDesc:SetWidth(FRAME_W - PAD * 2 - 30)
stickLastDesc:SetJustifyH("LEFT")
stickLastDesc:SetText("When off, the sequence loops back to position 1 after the last entry.")
stickLastDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
stickLastDesc:Hide()

local piEnableLine = UI:MakeLine(piPanel, C.border, 1)
piEnableLine:SetPoint("TOPLEFT",  stickLastDesc, "BOTTOMLEFT",  -26, -8)
piEnableLine:SetPoint("TOPRIGHT", piPanel, "TOPRIGHT", -PAD, -8)

-- Scroll frame for list + alert settings
local piScroll = CreateFrame("ScrollFrame", nil, piPanel, "UIPanelScrollFrameTemplate")
piScroll:SetPoint("TOPLEFT",     piEnableLine, "BOTTOMLEFT",  0, -4)
piScroll:SetPoint("BOTTOMRIGHT", piPanel,      "BOTTOMRIGHT", -PAD - 16, PAD)

local piScrollChild = CreateFrame("Frame", nil, piScroll)
piScrollChild:SetWidth(FRAME_W - PAD * 2 - 20)
piScrollChild:SetHeight(1) -- will grow with content
piScroll:SetScrollChild(piScrollChild)

-- Priority list inside scroll child
-- List scroll frame (fixed height, clips rows, scrolls if list grows)
local listScroll = CreateFrame("ScrollFrame", nil, piScrollChild, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT",  piScrollChild, "TOPLEFT",  0, 0)
listScroll:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT", -16, 0)
listScroll:SetHeight(180)

local listFrame = CreateFrame("Frame", nil, listScroll)
listFrame:SetWidth(FRAME_W - PAD * 2 - 36)
listFrame:SetHeight(1)  -- grows with content
listScroll:SetScrollChild(listFrame)
UI:MakeBg(listFrame, {0, 0, 0, 0.25})

-- Row pool
local listRows = {}
local DRAG_INDEX = nil

RefreshList = function()
    if not PWT.db then return end
    local mode = PWT.db.piMode or "priority"
    local list = mode == "sequence" and PWT.db.piSequenceList or PWT.db.piList

    -- Hide all pooled rows first so switching between lists is clean
    for _, row in ipairs(listRows) do
        row:Hide()
        row:ClearAllPoints()
    end

    for i, name in ipairs(list) do
        local row = listRows[i]
        if not row then
            row = CreateFrame("Button", nil, listFrame)
            row:SetHeight(30)
            row:SetWidth(FRAME_W - PAD * 2 - 36)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            local badge = row:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
            badge:SetPoint("LEFT", row, "LEFT", 8, 0)
            badge:SetWidth(16)
            badge:SetJustifyH("RIGHT")
            badge:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
            row.badge = badge

            local label = row:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
            label:SetPoint("LEFT",  badge, "RIGHT", 8, 0)
            label:SetPoint("RIGHT", row, "RIGHT", -30, 0)
            label:SetJustifyH("LEFT")
            label:SetTextColor(C.text[1], C.text[2], C.text[3])
            row.label = label

            local removeBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            removeBtn:SetSize(20, 20)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            removeBtn:SetScript("OnClick", function()
                local m = PWT.db.piMode or "priority"
                local l = m == "sequence" and PWT.db.piSequenceList or PWT.db.piList
                table.remove(l, row.index)
                RefreshList()
                if m == "sequence" then UpdateSeqIndexLabel() end
            end)

            row:SetMovable(true)
            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function(self)
                DRAG_INDEX = self.index
                self:StartMoving()
                self:SetFrameLevel(self:GetFrameLevel() + 10)
            end)
            row:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                self:SetFrameLevel(math.max(0, self:GetFrameLevel() - 10))
                local selfMid = (self:GetTop() + self:GetBottom()) / 2
                local bestIndex = DRAG_INDEX
                local bestDist  = math.huge
                for j, other in ipairs(listRows) do
                    if other:IsShown() and j ~= DRAG_INDEX then
                        local otherMid = ((other:GetTop() or 0) + (other:GetBottom() or 0)) / 2
                        local dist = math.abs(otherMid - selfMid)
                        if dist < bestDist then
                            bestDist  = dist
                            bestIndex = j
                        end
                    end
                end
                if bestIndex ~= DRAG_INDEX then
                    local m = PWT.db.piMode or "priority"
                    local l = m == "sequence" and PWT.db.piSequenceList or PWT.db.piList
                    local item = table.remove(l, DRAG_INDEX)
                    table.insert(l, bestIndex, item)
                end
                DRAG_INDEX = nil
                RefreshList()
            end)

            listRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -((i - 1) * 30))
        row:SetWidth(FRAME_W - PAD * 2 - 36)
        row.index = i
        row.badge:SetText(tostring(i))
        -- In sequence mode, highlight the current target position
        if mode == "sequence" and i == (PWT.PI and PWT.PI.sequenceIndex or 1) then
            row.label:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            row.badge:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        else
            row.label:SetTextColor(C.text[1], C.text[2], C.text[3])
            row.badge:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
        end
        row.label:SetText(name)
        row.bg:SetColorTexture(
            i % 2 == 0 and C.rowEven[1] or C.rowOdd[1],
            i % 2 == 0 and C.rowEven[2] or C.rowOdd[2],
            i % 2 == 0 and C.rowEven[3] or C.rowOdd[3],
            i % 2 == 0 and C.rowEven[4] or C.rowOdd[4]
        )
        row:Show()
    end

    -- Grow the scroll child to fit all rows
    local totalH = math.max(#list * 30, 1)
    listFrame:SetHeight(totalH)

    for i = #list + 1, #listRows do
        listRows[i]:Hide()
        listRows[i]:ClearAllPoints()
    end
end

-- ── Alert Settings (collapsible) ────────────────────────────────────────




local alertCollapsed   = true  -- default collapsed
local overlayCollapsed = true
local PI_SyncAlerts    -- forward declaration — assigned after controls are built
local PI_SyncOverlay   -- forward declaration — assigned after overlay section is built
local UpdateScrollHeight  -- forward declaration — assigned after overlay section is built

local alertLine = UI:MakeLine(piScrollChild, C.border, 1)
alertLine:SetPoint("TOPLEFT",  listScroll, "BOTTOMLEFT",  0, -12)
alertLine:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT", 0, -12)

-- Collapsible header button
local alertToggleBtn = CreateFrame("Button", nil, piScrollChild)
alertToggleBtn:SetPoint("TOPLEFT", alertLine, "BOTTOMLEFT", 0, -6)
alertToggleBtn:SetHeight(22)
alertToggleBtn:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT", 0, -6)

local alertArrow = alertToggleBtn:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
alertArrow:SetPoint("LEFT", alertToggleBtn, "LEFT", 0, 0)
alertArrow:SetText("|cffcc99ff+ Alert Settings|r")

local alertHeaderHint = alertToggleBtn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
alertHeaderHint:SetPoint("RIGHT", alertToggleBtn, "RIGHT", 0, 0)
alertHeaderHint:SetText("click to expand")
alertHeaderHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Alert content container (shown/hidden by toggle)
local alertContent = CreateFrame("Frame", nil, piScrollChild)
alertContent:SetPoint("TOPLEFT",  alertToggleBtn, "BOTTOMLEFT",  0, -6)
alertContent:SetPoint("TOPRIGHT", piScrollChild,  "TOPRIGHT", 0, -6)
alertContent:SetHeight(390)  -- tall enough for all controls
alertContent:Hide()  -- collapsed by default

local ReanchorOverlayLine  -- forward ref

local function UpdateAlertToggle()
    if alertCollapsed then
        alertArrow:SetText("|cffcc99ff+ Alert Settings|r")
        alertHeaderHint:SetText("click to expand")
        alertContent:Hide()
    else
        alertArrow:SetText("|cffcc99ff- Alert Settings|r")
        alertHeaderHint:SetText("click to collapse")
        alertContent:Show()
    end
    if ReanchorOverlayLine then ReanchorOverlayLine() end
    if UpdateScrollHeight then UpdateScrollHeight() end
end

alertToggleBtn:SetScript("OnClick", function()
    alertCollapsed = not alertCollapsed
    UpdateAlertToggle()
end)
alertToggleBtn:SetScript("OnEnter", function()
    alertArrow:SetText("|cffffffff" .. (alertCollapsed and "+ Alert Settings" or "- Alert Settings") .. "|r")
end)
alertToggleBtn:SetScript("OnLeave", function()
    alertArrow:SetText("|cffcc99ff" .. (alertCollapsed and "+ Alert Settings" or "- Alert Settings") .. "|r")
end)

-- ── Glow section ─────────────────────────────────────────────────────

local glowSectionLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
glowSectionLabel:SetPoint("TOPLEFT", alertContent, "TOPLEFT", 0, 0)
glowSectionLabel:SetText("Glow")
glowSectionLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

local glowEnableCheck = CreateFrame("CheckButton", nil, alertContent, "UICheckButtonTemplate")
glowEnableCheck:SetPoint("TOPLEFT", glowSectionLabel, "BOTTOMLEFT", -2, -4)
glowEnableCheck.text:SetText("Enable glow on raid frame")
glowEnableCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
glowEnableCheck:SetScript("OnClick", function(self)
    PWT.db.pi.glowEnabled = self:GetChecked()
end)

-- Style selector — two buttons side by side
local styleLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
styleLabel:SetPoint("TOPLEFT", glowEnableCheck, "BOTTOMLEFT", 26, -6)
styleLabel:SetText("Style:")
styleLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local GLOW_STYLES = {
    { key="overlay", label="Full Overlay" },
    { key="border",  label="Outer Glow"   },
}

local styleButtons = {}
local UpdateVarSlider  -- forward declaration
local function UpdateStyleButtons()
    local current = PWT.db and PWT.db.pi and PWT.db.pi.glowStyle or "overlay"
    for _, btn in ipairs(styleButtons) do
        if btn.styleKey == current then
            btn:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            btn.bg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.9)
        else
            btn:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
            btn.bg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
        end
    end
    if UpdateVarSlider then UpdateVarSlider() end
end

for i, style in ipairs(GLOW_STYLES) do
    local btn = CreateFrame("Button", nil, alertContent)
    btn:SetSize(100, 22)
    if i == 1 then
        btn:SetPoint("LEFT", styleLabel, "RIGHT", 8, 0)
    else
        btn:SetPoint("LEFT", styleButtons[i-1], "RIGHT", 6, 0)
    end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
    btn.bg = bg

    local lbl = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetAllPoints(btn)
    lbl:SetJustifyH("CENTER")
    lbl:SetText(style.label)
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    btn.SetTextColor = function(self, r, g, b) lbl:SetTextColor(r, g, b) end

    btn.styleKey = style.key
    btn:SetScript("OnClick", function()
        PWT.db.pi.glowStyle = style.key
        UpdateStyleButtons()
    end)
    btn:SetScript("OnEnter", function(self)
        if (PWT.db.pi.glowStyle or "overlay") ~= style.key then
            self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.7)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if (PWT.db.pi.glowStyle or "overlay") ~= style.key then
            self.bg:SetColorTexture(0.1, 0.1, 0.12, 0.8)
        end
    end)

    styleButtons[i] = btn
end

-- ── Row helper: creates a label + slider row anchored below 'anchor'
local function makeSliderRow(anchor, labelText, minV, maxV, step, lowText, highText, onChange)
    local row = CreateFrame("Frame", nil, alertContent)
    row:SetHeight(36)
    row:SetPoint("TOPLEFT",  anchor, "BOTTOMLEFT",  0, -10)
    row:SetPoint("TOPRIGHT", alertContent, "TOPRIGHT", 0, -10)

    local lbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -10)
    lbl:SetText(labelText)
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    row.label = lbl

    local sl = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
    sl:SetSize(140, 16)
    sl:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)
    sl.Low:SetText(lowText)
    sl.High:SetText(highText)
    sl.Text:SetText("")
    sl:SetScript("OnValueChanged", onChange)
    row.slider = sl
    return row
end

-- Color row
local colorRow = CreateFrame("Frame", nil, alertContent)
colorRow:SetHeight(26)
colorRow:SetPoint("TOPLEFT",  styleLabel, "BOTTOMLEFT",  0, -12)
colorRow:SetPoint("TOPRIGHT", alertContent, "TOPRIGHT", 0, -12)

local colorLabel = colorRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
colorLabel:SetPoint("TOPLEFT", colorRow, "TOPLEFT", 0, -4)
colorLabel:SetText("Color:")
colorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local colorSwatch = CreateFrame("Button", nil, colorRow)
colorSwatch:SetSize(26, 26)
colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)

local colorSwatchTex = colorSwatch:CreateTexture(nil, "ARTWORK")
colorSwatchTex:SetAllPoints(colorSwatch)
colorSwatchTex:SetColorTexture(1.0, 0.85, 0.0, 1.0)
local colorSwatchBorder = colorSwatch:CreateTexture(nil, "OVERLAY")
colorSwatchBorder:SetAllPoints(colorSwatch)
colorSwatchBorder:SetColorTexture(1, 1, 1, 0.4)

local colorPickerHint = colorRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
colorPickerHint:SetPoint("LEFT", colorSwatch, "RIGHT", 8, 0)
colorPickerHint:SetText("Click to choose")
colorPickerHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local function OpenColorPicker()
    local cfg = PWT.db.pi
    local r, g, b = cfg.glowR or 1, cfg.glowG or 0.85, cfg.glowB or 0
    local function OnColorChanged(restore)
        local nr, ng, nb
        if restore then nr, ng, nb = r, g, b
        else nr, ng, nb = ColorPickerFrame:GetColorRGB() end
        PWT.db.pi.glowR = nr
        PWT.db.pi.glowG = ng
        PWT.db.pi.glowB = nb
        colorSwatchTex:SetColorTexture(nr, ng, nb, 1.0)
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ hasOpacity=false, r=r, g=g, b=b,
            swatchFunc=OnColorChanged, cancelFunc=function() OnColorChanged(true) end })
    else
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.func       = OnColorChanged
        ColorPickerFrame.cancelFunc = function() OnColorChanged(true) end
        ColorPickerFrame.hasOpacity = false
        ShowUIPanel(ColorPickerFrame)
    end
end
colorSwatch:SetScript("OnClick", OpenColorPicker)
colorSwatch:SetScript("OnEnter", function()
    GameTooltip:SetOwner(colorSwatch, "ANCHOR_RIGHT")
    GameTooltip:SetText("Click to open color picker")
    GameTooltip:Show()
end)
colorSwatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Opacity row (overlay mode)
local opacityRow = makeSliderRow(colorRow, "Opacity:", 0.1, 1.0, 0.05, "10%", "100%",
    function(self, val)
        PWT.db.pi.glowOpacity = val
        self.Text:SetText(string.format("%d%%", math.floor(val * 100 + 0.5)))
    end)
local opacitySlider = opacityRow.slider

-- Thickness row (border mode) — same position as opacity row, swapped in/out
local thickRow = makeSliderRow(colorRow, "Thickness:", 1, 10, 1, "1", "10",
    function(self, val)
        val = math.floor(val + 0.5)
        if PWT.db and PWT.db.pi then PWT.db.pi.borderThickness = val end
        self.Text:SetText(tostring(val) .. "px")
    end)
local thickSlider = thickRow.slider
thickRow:Hide()

UpdateVarSlider = function()
    if not PWT.db or not PWT.db.pi then return end
    local mode = PWT.db.pi.glowStyle or "overlay"
    if mode == "border" then
        opacityRow:Hide()
        thickRow:Show()
        thickSlider:SetValue(PWT.db.pi.borderThickness or 3)
    else
        thickRow:Hide()
        opacityRow:Show()
        opacitySlider:SetValue(PWT.db.pi.glowOpacity or 0.55)
    end
end

-- Pulse row
-- varSpacer: fixed-height invisible frame that sits below colorRow,
-- giving pulseRow a stable anchor regardless of which var row is shown
local varSpacer = CreateFrame("Frame", nil, alertContent)
varSpacer:SetHeight(46)
varSpacer:SetPoint("TOPLEFT",  colorRow, "BOTTOMLEFT",  0, -10)
varSpacer:SetPoint("TOPRIGHT", alertContent, "TOPRIGHT", 0, -10)

-- Re-anchor opacity and thick rows inside varSpacer
opacityRow:ClearAllPoints()
opacityRow:SetPoint("TOPLEFT",  varSpacer, "TOPLEFT",  0, 0)
opacityRow:SetPoint("TOPRIGHT", varSpacer, "TOPRIGHT", 0, 0)
thickRow:ClearAllPoints()
thickRow:SetPoint("TOPLEFT",  varSpacer, "TOPLEFT",  0, 0)
thickRow:SetPoint("TOPRIGHT", varSpacer, "TOPRIGHT", 0, 0)

local pulseRow = makeSliderRow(varSpacer, "Pulse:", 0.1, 2.0, 0.1, "Fast", "Slow",
    function(self, val)
        PWT.db.pi.glowPulse = val
        self.Text:SetText(string.format("%.1fs", val))
    end)
local pulseSlider = pulseRow.slider

local glowTestBtn = CreateFrame("Button", nil, alertContent, "UIPanelButtonTemplate")
glowTestBtn:SetSize(60, 22)
glowTestBtn:SetPoint("LEFT", pulseSlider, "RIGHT", 10, 0)
glowTestBtn:SetText("Test")
glowTestBtn:SetScript("OnClick", function()
    PWT.PI:BuildSoundList()
    local unitToken = "player"
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsUnit("raid"..i, "player") then
                unitToken = "raid"..i
                break
            end
        end
    end
    local playerName = GetUnitName("player", false) or "preview"
    PWT.PI:ClearGlow(playerName)
    local testFrame = PWT.RaidFrames:Find(unitToken)
    if testFrame then
        PWT.PI:ApplyGlow(testFrame, playerName)
    else
        if PWT.db.pi.soundEnabled ~= false then
            PWT.PI:PlayCurrentSound()
        end
        PWT:Print("No raid frame found — sound only. Join a group to test the glow.")
    end
end)

-- Glow reset to defaults
local glowResetBtn = CreateFrame("Button", nil, alertContent, "UIPanelButtonTemplate")
glowResetBtn:SetSize(80, 22)
glowResetBtn:SetPoint("TOPLEFT", pulseRow, "BOTTOMLEFT", 0, -10)
glowResetBtn:SetText("Reset Glow")
glowResetBtn:SetScript("OnClick", function()
    PWT.db.pi.glowEnabled      = true
    PWT.db.pi.glowStyle        = "overlay"
    PWT.db.pi.borderThickness  = 3
    PWT.db.pi.glowR            = 1.0
    PWT.db.pi.glowG            = 0.85
    PWT.db.pi.glowB            = 0.0
    PWT.db.pi.glowOpacity      = 0.55
    PWT.db.pi.glowPulse        = 0.6
    PI_SyncAlerts()
    PWT:Print("Glow settings reset to defaults.")
end)

-- ── Sound section ─────────────────────────────────────────────────────

local soundSectionLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
soundSectionLabel:SetPoint("TOPLEFT", glowResetBtn, "BOTTOMLEFT", 0, -14)
soundSectionLabel:SetText("Sound")
soundSectionLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

local soundEnableCheck = CreateFrame("CheckButton", nil, alertContent, "UICheckButtonTemplate")
soundEnableCheck:SetPoint("TOPLEFT", soundSectionLabel, "BOTTOMLEFT", -2, -4)
soundEnableCheck.text:SetText("Enable alert sound")
soundEnableCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
soundEnableCheck:SetScript("OnClick", function(self)
    PWT.db.pi.soundEnabled = self:GetChecked()
end)





-- Dropdown button (custom styled to match the UI)
local soundDropLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
soundDropLabel:SetPoint("TOPLEFT", soundEnableCheck, "BOTTOMLEFT", 26, -6)
soundDropLabel:SetText("Sound:")
soundDropLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local soundDropBtn = CreateFrame("Button", nil, alertContent, "UIPanelButtonTemplate")
soundDropBtn:SetSize(180, 22)
soundDropBtn:SetPoint("LEFT", soundDropLabel, "RIGHT", 8, 0)

local soundDropBtnText = soundDropBtn:GetFontString()
soundDropBtnText:SetText("Alarm Clock")

local soundPreviewBtn = CreateFrame("Button", nil, alertContent, "UIPanelButtonTemplate")
soundPreviewBtn:SetSize(60, 22)
soundPreviewBtn:SetPoint("LEFT", soundDropBtn, "RIGHT", 6, 0)
soundPreviewBtn:SetText("Preview")
soundPreviewBtn:SetScript("OnClick", function() PWT.PI:PlayCurrentSound() end)

local function UpdateDropLabel()
    local idx = PWT.db and PWT.db.pi and PWT.db.pi.soundIndex or 5
    local entry = PWT.PI.soundList[idx]
    local name = entry and entry.label or "Unknown"
    -- Truncate if too long for the button
    if #name > 28 then
        name = name:sub(1, 25) .. "..."
    end
    soundDropBtnText:SetText(name)
end

-- ── Custom scrollable dropdown ────────────────────────────────
local DROPDOWN_H    = 200
local ROW_H         = 20
local dropPanel = CreateFrame("Frame", "PWT_SoundDropPanel", UIParent)
dropPanel:SetSize(248, DROPDOWN_H)
dropPanel:SetFrameStrata("TOOLTIP")
dropPanel:SetFrameLevel(100)
dropPanel:Hide()

UI:MakeBg(dropPanel, {0.06, 0.06, 0.08, 0.98})
local dropBorder = dropPanel:CreateTexture(nil, "OVERLAY")
dropBorder:SetAllPoints(dropPanel)
dropBorder:SetColorTexture(0, 0, 0, 0)
local function addDropLine(p1, rP, ox, oy)
    local t = dropPanel:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
    t:SetHeight(1)
    t:SetPoint(p1, dropPanel, rP, ox, oy)
    t:SetPoint(p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT",
               dropPanel, p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", -ox, oy)
end
addDropLine("TOPLEFT",    "TOPLEFT",    0,  0)
addDropLine("BOTTOMLEFT", "BOTTOMLEFT", 0,  0)

local dropScroll = CreateFrame("ScrollFrame", nil, dropPanel, "UIPanelScrollFrameTemplate")
dropScroll:SetPoint("TOPLEFT",     dropPanel, "TOPLEFT",     4, -4)
dropScroll:SetPoint("BOTTOMRIGHT", dropPanel, "BOTTOMRIGHT", -22, 4)

local DROP_ROW_W = 218  -- fixed width matching panel minus scrollbar
local dropChild = CreateFrame("Frame", nil, dropScroll)
dropChild:SetWidth(DROP_ROW_W)
dropChild:SetHeight(1)
dropScroll:SetScrollChild(dropChild)

local dropRows = {}

local function HideDropdown()
    dropPanel:Hide()
end

local function PopulateDropdown()
    for _, r in ipairs(dropRows) do r:Hide() end
    wipe(dropRows)

    local currentIdx = PWT.db and PWT.db.pi and PWT.db.pi.soundIndex or 5

    local soundList = PWT.PI.soundList
    for i, entry in ipairs(soundList) do
        local row = CreateFrame("Button", nil, dropChild)
        row:SetSize(DROP_ROW_W, ROW_H)
        row:SetPoint("TOPLEFT", dropChild, "TOPLEFT", 0, -(i - 1) * ROW_H)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        row.bg = rowBg

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        rowLabel:SetPoint("LEFT",  row, "LEFT",  6, 0)
        rowLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rowLabel:SetJustifyH("LEFT")

        if i == currentIdx then
            rowBg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.8)
            rowLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        else
            rowBg:SetColorTexture(0, 0, 0, 0)
            rowLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
        rowLabel:SetText(entry.label)

        row:SetScript("OnEnter", function(self)
            if i ~= (PWT.db.pi.soundIndex or 5) then
                self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if i ~= (PWT.db.pi.soundIndex or 5) then
                self.bg:SetColorTexture(0, 0, 0, 0)
            end
        end)
        row:SetScript("OnClick", function()
            PWT.db.pi.soundIndex = i
            UpdateDropLabel()
            HideDropdown()
        end)

        row:Show()
        dropRows[i] = row
    end

    local totalH = #soundList * ROW_H
    dropChild:SetHeight(math.max(totalH, 1))

    -- Scroll to show selected entry
    local scrollMax = math.max(0, totalH - DROPDOWN_H + 8)
    local scrollTo  = math.max(0, math.min(scrollMax, (currentIdx - 1) * ROW_H - DROPDOWN_H / 2))
    dropScroll:SetVerticalScroll(scrollTo)
end

soundDropBtn:SetScript("OnClick", function(self)
    if dropPanel:IsShown() then
        HideDropdown()
        return
    end
    PWT.PI:BuildSoundList()
    PopulateDropdown()
    dropPanel:ClearAllPoints()
    dropPanel:SetPoint("TOPLEFT", soundDropBtn, "BOTTOMLEFT", 0, -2)
    dropPanel:Show()
    dropPanel:SetScript("OnLeave", nil)
end)

-- Close dropdown when clicking elsewhere
dropPanel:SetScript("OnHide", function() end)
local dropWatcher = CreateFrame("Frame", nil, UIParent)
dropWatcher:SetAllPoints(UIParent)
dropWatcher:SetFrameStrata("DIALOG")
dropWatcher:EnableMouse(false)
dropWatcher:Hide()
dropPanel:HookScript("OnShow", function()
    dropWatcher:EnableMouse(true)
    dropWatcher:Show()
    dropWatcher:SetScript("OnMouseDown", function(self, btn)
        HideDropdown()
        self:EnableMouse(false)
        self:Hide()
    end)
end)
dropPanel:HookScript("OnHide", function()
    dropWatcher:EnableMouse(false)
    dropWatcher:Hide()
end)

local volLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
volLabel:SetPoint("TOPLEFT", soundDropLabel, "BOTTOMLEFT", 0, -18)
volLabel:SetText("Volume:")
volLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local volSlider = CreateFrame("Slider", nil, alertContent, "OptionsSliderTemplate")
volSlider:SetSize(140, 16)
volSlider:SetPoint("LEFT", volLabel, "RIGHT", 8, 0)
volSlider:SetMinMaxValues(0.0, 1.0)
volSlider:SetValueStep(0.05)
volSlider:SetObeyStepOnDrag(true)
volSlider.Low:SetText("0%")
volSlider.High:SetText("100%")
volSlider.Text:SetText("")
volSlider:SetScript("OnValueChanged", function(self, val)
    PWT.db.pi.soundVolume = val
    self.Text:SetText(string.format("%d%%", math.floor(val * 100 + 0.5)))
end)

-- Sound reset to defaults
local soundResetBtn = CreateFrame("Button", nil, alertContent, "UIPanelButtonTemplate")
soundResetBtn:SetSize(90, 22)
soundResetBtn:SetPoint("TOPLEFT", volLabel, "BOTTOMLEFT", -26, -18)
soundResetBtn:SetText("Reset Sound")
soundResetBtn:SetScript("OnClick", function()
    PWT.db.pi.soundEnabled = true
    PWT.db.pi.soundIndex   = 5
    PWT.db.pi.soundVolume  = 1.0
    PI_SyncAlerts()
    PWT:Print("Sound settings reset to defaults.")
end)



-- Sync all PI alert controls when tab opens
-- Fills the forward declaration above
PI_SyncAlerts = function()
    if not PWT.db or not PWT.db.pi then return end
    local cfg = PWT.db.pi
    glowEnableCheck:SetChecked(cfg.glowEnabled ~= false)
    soundEnableCheck:SetChecked(cfg.soundEnabled ~= false)
    pulseSlider:SetValue(cfg.glowPulse or 0.6)
    volSlider:SetValue(cfg.soundVolume or 1.0)
    PWT.PI:BuildSoundList()
    UpdateDropLabel()
    UpdateStyleButtons()  -- also calls UpdateVarSlider
    colorSwatchTex:SetColorTexture(cfg.glowR or 1, cfg.glowG or 0.85, cfg.glowB or 0, 1.0)
end

-- ── Name Overlay section ─────────────────────────────────────────────────

local overlayLine = UI:MakeLine(piScrollChild, C.border, 1)
overlayLine:SetPoint("TOPLEFT",  alertToggleBtn, "BOTTOMLEFT",  0, -12)
overlayLine:SetPoint("TOPRIGHT", piScrollChild,  "TOPRIGHT",    0, -12)

ReanchorOverlayLine = function()
    overlayLine:ClearAllPoints()
    if alertCollapsed then
        overlayLine:SetPoint("TOPLEFT",  alertToggleBtn, "BOTTOMLEFT",  0, -12)
    else
        overlayLine:SetPoint("TOPLEFT",  soundResetBtn,  "BOTTOMLEFT",  0, -12)
    end
    overlayLine:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT", 0, -12)
end

local overlayToggleBtn = CreateFrame("Button", nil, piScrollChild)
overlayToggleBtn:SetPoint("TOPLEFT",  overlayLine, "BOTTOMLEFT",  0, -6)
overlayToggleBtn:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT",  0, -6)
overlayToggleBtn:SetHeight(22)

local overlayArrow = overlayToggleBtn:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
overlayArrow:SetPoint("LEFT", overlayToggleBtn, "LEFT", 0, 0)
overlayArrow:SetText("|cffcc99ff+ Name Overlay|r")

local overlayHeaderHint = overlayToggleBtn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
overlayHeaderHint:SetPoint("RIGHT", overlayToggleBtn, "RIGHT", 0, 0)
overlayHeaderHint:SetText("click to expand")
overlayHeaderHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local overlayContent = CreateFrame("Frame", nil, piScrollChild)
overlayContent:SetPoint("TOPLEFT",  overlayToggleBtn, "BOTTOMLEFT",  0, -6)
overlayContent:SetPoint("TOPRIGHT", piScrollChild,    "TOPRIGHT",    0, -6)
overlayContent:SetHeight(130)
overlayContent:Hide()

-- Forward declare for cross-ref between enable check and lock button
local overlayLocked = true
local overlayLockBtn  -- assigned below

local overlayEnableCheck = CreateFrame("CheckButton", nil, overlayContent, "UICheckButtonTemplate")
overlayEnableCheck:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", 0, 0)
overlayEnableCheck.text:SetText("Show floating name overlay")
overlayEnableCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
overlayEnableCheck:SetScript("OnClick", function(self)
    PWT.db.pi.overlayEnabled = self:GetChecked()
    if not self:GetChecked() then
        PWT.PI:ForceHideOverlay()
        overlayLockBtn:SetText("Unlock to Move")
        overlayLocked = true
    end
end)

local overlayEnableDesc = overlayContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
overlayEnableDesc:SetPoint("TOPLEFT", overlayEnableCheck, "BOTTOMLEFT", 26, -2)
overlayEnableDesc:SetWidth(FRAME_W - PAD * 2 - 30)
overlayEnableDesc:SetJustifyH("LEFT")
overlayEnableDesc:SetText("Displays a floating frame with the PI target's name and spell icon.")
overlayEnableDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local overlaySizeLabel = overlayContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
overlaySizeLabel:SetPoint("TOPLEFT", overlayEnableDesc, "BOTTOMLEFT", 0, -10)
overlaySizeLabel:SetText("Font Size:")
overlaySizeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local overlaySizeSlider = CreateFrame("Slider", nil, overlayContent, "OptionsSliderTemplate")
overlaySizeSlider:SetSize(140, 16)
overlaySizeSlider:SetPoint("LEFT", overlaySizeLabel, "RIGHT", 8, 0)
overlaySizeSlider:SetMinMaxValues(10, 48)
overlaySizeSlider:SetValueStep(1)
overlaySizeSlider:SetObeyStepOnDrag(true)
overlaySizeSlider.Low:SetText("10")
overlaySizeSlider.High:SetText("48")
overlaySizeSlider.Text:SetText("")
overlaySizeSlider:SetScript("OnValueChanged", function(self, val)
    val = math.floor(val + 0.5)
    if PWT.db and PWT.db.pi then PWT.db.pi.overlayFontSize = val end
    self.Text:SetText(tostring(val) .. "px")
    PWT.PI:UpdateOverlayFont()
end)

overlayLockBtn = CreateFrame("Button", nil, overlayContent, "UIPanelButtonTemplate")
overlayLockBtn:SetSize(120, 24)
overlayLockBtn:SetPoint("TOPLEFT", overlaySizeLabel, "BOTTOMLEFT", 0, -14)
overlayLockBtn:SetText("Unlock to Move")
overlayLockBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.pi and PWT.db.pi.overlayEnabled) then
        PWT:Print("Enable the overlay first.")
        return
    end
    overlayLocked = not overlayLocked
    PWT.PI:CreateOverlayWidget()
    if not overlayLocked then
        overlayLockBtn:SetText("Lock Position")
        overlayLockBtn:GetFontString():SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        PWT.PI:SetOverlayMovable(true)
        PWT.PI:ShowOverlay(GetUnitName("player", false) or "Preview")
    else
        overlayLockBtn:SetText("Unlock to Move")
        overlayLockBtn:GetFontString():SetTextColor(1, 1, 1)
        PWT.PI:SetOverlayMovable(false)
        PWT.PI:ForceHideOverlay()
    end
end)

local overlayPreviewBtn = CreateFrame("Button", nil, overlayContent, "UIPanelButtonTemplate")
overlayPreviewBtn:SetSize(80, 24)
overlayPreviewBtn:SetPoint("LEFT", overlayLockBtn, "RIGHT", 8, 0)
overlayPreviewBtn:SetText("Preview")
overlayPreviewBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.pi and PWT.db.pi.overlayEnabled) then
        PWT:Print("Enable the overlay first.")
        return
    end
    PWT.PI:CreateOverlayWidget()
    PWT.PI:ShowOverlay(GetUnitName("player", false) or "Preview")
    C_Timer.After(5, function()
        if overlayLocked then PWT.PI:ForceHideOverlay() end
    end)
end)

local function UpdateOverlayToggle()
    if overlayCollapsed then
        overlayArrow:SetText("|cffcc99ff+ Name Overlay|r")
        overlayHeaderHint:SetText("click to expand")
        overlayContent:Hide()
    else
        overlayArrow:SetText("|cffcc99ff- Name Overlay|r")
        overlayHeaderHint:SetText("click to collapse")
        overlayContent:Show()
    end
    if UpdateScrollHeight then UpdateScrollHeight() end
end

overlayToggleBtn:SetScript("OnClick", function()
    overlayCollapsed = not overlayCollapsed
    UpdateOverlayToggle()
end)
overlayToggleBtn:SetScript("OnEnter", function()
    overlayArrow:SetText("|cffffffff" .. (overlayCollapsed and "+ Name Overlay" or "- Name Overlay") .. "|r")
end)
overlayToggleBtn:SetScript("OnLeave", function()
    overlayArrow:SetText("|cffcc99ff" .. (overlayCollapsed and "+ Name Overlay" or "- Name Overlay") .. "|r")
end)

PI_SyncOverlay = function()
    if not PWT.db or not PWT.db.pi then return end
    overlayEnableCheck:SetChecked(PWT.db.pi.overlayEnabled == true)
    overlaySizeSlider:SetValue(PWT.db.pi.overlayFontSize or 24)
end

UpdateScrollHeight = function()
    local base = listScroll:GetHeight() + 60
    if not alertCollapsed   then base = base + alertContent:GetHeight()   + 16 end
    base = base + 40  -- overlay separator line + toggle button
    if not overlayCollapsed then base = base + overlayContent:GetHeight() + 8  end
    piScrollChild:SetHeight(base)
end

-- Initialise collapsed height
UpdateAlertToggle()

-- Show/hide footer controls when switching tabs
local AT_SyncOptions  -- forward declaration, defined after atonement tab is built

-- ── Footer controls (PI tab) ─────────────────────────────────
local piFooterControls = CreateFrame("Frame", nil, UI.footer)
piFooterControls:SetAllPoints(UI.footer)
piFooterControls:Hide()

local addBox = CreateFrame("EditBox", nil, piFooterControls, "InputBoxTemplate")
addBox:SetSize(220, 24)
addBox:SetPoint("LEFT", piFooterControls, "LEFT", PAD + 4, 0)
addBox:SetAutoFocus(false)
addBox:SetMaxLetters(64)
addBox:SetScript("OnEnterPressed", function(self)
    local name = strtrim(self:GetText())
    if name ~= "" then
        local m = PWT.db.piMode or "priority"
        local l = m == "sequence" and PWT.db.piSequenceList or PWT.db.piList
        table.insert(l, name)
        self:SetText("")
        RefreshList()
        if m == "sequence" then UpdateSeqIndexLabel() end
    end
end)

local addHint = addBox:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
addHint:SetPoint("LEFT", addBox, "LEFT", 4, 0)
addHint:SetText("Player name...")
addHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
addBox:SetScript("OnTextChanged", function(self)
    addHint:SetShown(self:GetText() == "")
end)

local addBtn = CreateFrame("Button", nil, piFooterControls, "UIPanelButtonTemplate")
addBtn:SetSize(70, 26)
addBtn:SetPoint("LEFT", addBox, "RIGHT", 8, 0)
addBtn:SetText("Add")
addBtn:SetScript("OnClick", function()
    local name = strtrim(addBox:GetText())
    if name ~= "" then
        local m = PWT.db.piMode or "priority"
        local l = m == "sequence" and PWT.db.piSequenceList or PWT.db.piList
        table.insert(l, name)
        addBox:SetText("")
        RefreshList()
        if m == "sequence" then UpdateSeqIndexLabel() end
    end
end)

-- Store footer controls on UI for show/hide by SwitchTab
UI.piFooterControls = piFooterControls

-- Called by UI.SwitchTab when the PI tab becomes active
function UI:SyncPI()
    piFooterControls:Show()
    modePriorityBtn:Show()
    modeSequenceBtn:Show()
    seqIndexLabel:SetShown(PWT.db and PWT.db.piMode == "sequence")
    RefreshList()
    if PWT.db then
        stickLastCheck:SetChecked(PWT.db.piSequenceStickLast or false)
        PI_SyncAlerts()
        PI_SyncOverlay()
        UpdateModeButtons()
        UpdateSeqIndexLabel()
    end
end

-- Allow UI:RefreshPI to call our local RefreshList
function UI:DoRefreshPI()
    RefreshList()
    UpdateSeqIndexLabel()
end