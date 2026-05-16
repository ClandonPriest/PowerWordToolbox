-- Power Word: Toolbox | Options/PI_Options.lua

local _, PWT = ...
local UI  = PWT.UI
local C   = UI.C
local PAD = UI.PAD
local CONTENT_W = UI.CONTENT_W

local piPanel = UI:AddTab("pi", "Power Infusion", 2)

local RefreshList  -- forward declaration, defined after row pool is built

local modeLabel = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modeLabel:SetPoint("TOPLEFT", piPanel, "TOPLEFT", 0, -PAD)
modeLabel:SetText("Mode:")
modeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Helper: build a border+fill mode button (same visual language as UI:MakeButton)
local function MakeModeButton(name, label, anchorLeft, anchorOffset)
    local btn = CreateFrame("Button", name, UI.optionsFrame)
    btn:SetSize(110, 26)
    btn:SetPoint("LEFT", anchorLeft, "RIGHT", anchorOffset, 0)
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(100)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)

    btn.fill = btn:CreateTexture(nil, "ARTWORK")
    btn.fill:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
    btn.fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    btn.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75)

    btn.lbl = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    btn.lbl:SetAllPoints(btn)
    btn.lbl:SetJustifyH("CENTER")
    btn.lbl:SetText(label)
    btn.lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    return btn
end

local modePriorityBtn = MakeModeButton("PWT_ModePriorityBtn", "Priority List", modeLabel, 8)
UI.modePriorityBtn = modePriorityBtn

local modeSequenceBtn = MakeModeButton("PWT_ModeSequenceBtn", "PI Sequence", modePriorityBtn, 6)
UI.modeSequenceBtn = modeSequenceBtn

local seqIndexLabel = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
UI.seqIndexLabel = seqIndexLabel
seqIndexLabel:SetPoint("LEFT", modeSequenceBtn, "RIGHT", 10, 0)
seqIndexLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
seqIndexLabel:Hide()

-- Mode description (dynamic)
local modeDescLabel = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modeDescLabel:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", 0, -20)
modeDescLabel:SetWidth(CONTENT_W - PAD * 2 - 20)
modeDescLabel:SetJustifyH("LEFT")
modeDescLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Forward-declared so UpdateModeButtons can reference them before they are created.
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

local function SetModeActive(btn, active)
    if active then
        btn.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.70)
        btn.fill:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 1.0)
        btn.lbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
    else
        btn.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)
        btn.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75)
        btn.lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    end
end

local function UpdateModeButtons()
    local mode = PWT.db and PWT.db.piMode or "priority"
    if mode == "priority" then
        SetModeActive(modePriorityBtn, true)
        SetModeActive(modeSequenceBtn, false)
        seqIndexLabel:Hide()
        stickLastCheck:Hide()
        stickLastDesc:Hide()
        modeDescLabel:SetText("When a group member whispers you in combat, the module glows the first player from your list who is currently in the group.")
    else
        SetModeActive(modeSequenceBtn, true)
        SetModeActive(modePriorityBtn, false)
        seqIndexLabel:Show()
        UpdateSeqIndexLabel()
        modeDescLabel:SetText("When a group member whispers you in combat, the module glows the next player in the sequence. Resets automatically on boss pull.")
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
    { btn = modePriorityBtn, key = "priority" },
    { btn = modeSequenceBtn, key = "sequence" },
}) do
    info.btn:SetScript("OnEnter", function()
        if (PWT.db.piMode or "priority") ~= info.key then
            info.btn.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.55)
            info.btn.fill:SetColorTexture(0.20, 0.15, 0.26, 0.85)
        end
    end)
    info.btn:SetScript("OnLeave", function()
        if (PWT.db.piMode or "priority") ~= info.key then
            info.btn.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)
            info.btn.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75)
        end
    end)
end

modePriorityBtn:Hide()
modeSequenceBtn:Hide()

-- Stick-to-last toggle (sequence mode only; forward-declared above)
stickLastCheck = UI:MakeCheckbox(piPanel, "Repeat last entry after sequence ends", nil, function(val)
    PWT.db.piSequenceStickLast = val
end)
stickLastCheck:SetPoint("TOPLEFT", modeDescLabel, "BOTTOMLEFT", 0, -4)
stickLastCheck:SetPoint("RIGHT",   piPanel, "RIGHT", -PAD, 0)
stickLastCheck:Hide()

stickLastDesc = piPanel:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
stickLastDesc:SetPoint("TOPLEFT", stickLastCheck, "BOTTOMLEFT", 22, -2)
stickLastDesc:SetWidth(CONTENT_W - PAD * 2 - 26)
stickLastDesc:SetJustifyH("LEFT")
stickLastDesc:SetText("When off, the sequence loops back to position 1 after the last entry.")
stickLastDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
stickLastDesc:Hide()

local piEnableLine = UI:MakeLine(piPanel, C.border, 1)
piEnableLine:SetPoint("TOPLEFT",  stickLastDesc, "BOTTOMLEFT",  -22, -8)
piEnableLine:SetPoint("TOPRIGHT", piPanel, "TOPRIGHT", -PAD, -8)

-- Scroll frame for list + add row + all settings sections
local piScroll = CreateFrame("ScrollFrame", nil, piPanel, "UIPanelScrollFrameTemplate")
piScroll:SetPoint("TOPLEFT",     piEnableLine, "BOTTOMLEFT",  0, -4)
piScroll:SetPoint("BOTTOMRIGHT", piPanel,      "BOTTOMRIGHT", -PAD - 16, PAD)
piScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
end)

local piScrollChild = CreateFrame("Frame", nil, piScroll)
piScrollChild:SetWidth(CONTENT_W - PAD * 2 - 20)
piScrollChild:SetHeight(1)
piScroll:SetScrollChild(piScrollChild)

-- List scroll frame (fixed height, clips rows, scrolls if list grows)
local listScroll = CreateFrame("ScrollFrame", nil, piScrollChild, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT",  piScrollChild, "TOPLEFT",  0, 0)
listScroll:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT", -16, 0)
listScroll:SetHeight(180)

local listFrame = CreateFrame("Frame", nil, listScroll)
listFrame:SetWidth(CONTENT_W - PAD * 2 - 36)
listFrame:SetHeight(1)
listScroll:SetScrollChild(listFrame)
UI:MakeBg(listFrame, {0, 0, 0, 0.25})

local listRows = {}
local DRAG_INDEX = nil

RefreshList = function()
    if not PWT.db then return end
    local mode = PWT.db.piMode or "priority"
    local list = mode == "sequence" and PWT.db.piSequenceList or PWT.db.piList

    for _, row in ipairs(listRows) do
        row:Hide()
        row:ClearAllPoints()
    end

    for i, name in ipairs(list) do
        local row = listRows[i]
        if not row then
            row = CreateFrame("Button", nil, listFrame)
            row:SetHeight(30)
            row:SetWidth(CONTENT_W - PAD * 2 - 36)

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
            label:SetPoint("RIGHT", row, "RIGHT", -24, 0)
            label:SetJustifyH("LEFT")
            label:SetTextColor(C.text[1], C.text[2], C.text[3])
            row.label = label

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(14, 14)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

            local removeBg = removeBtn:CreateTexture(nil, "BACKGROUND")
            removeBg:SetAllPoints(removeBtn)
            removeBg:SetColorTexture(0.60, 0.25, 0.25, 0.60)

            local removeLbl = removeBtn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
            removeLbl:SetAllPoints(removeBtn)
            removeLbl:SetJustifyH("CENTER")
            removeLbl:SetText("x")
            removeLbl:SetTextColor(C.text[1], C.text[2], C.text[3])

            removeBtn:SetScript("OnEnter", function()
                removeBg:SetColorTexture(C.danger[1], C.danger[2], C.danger[3], 0.90)
            end)
            removeBtn:SetScript("OnLeave", function()
                removeBg:SetColorTexture(0.60, 0.25, 0.25, 0.60)
            end)
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
        row:SetWidth(CONTENT_W - PAD * 2 - 36)
        row.index = i
        row.badge:SetText(tostring(i))
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
            i % 2 == 0 and C.rowEven[4] or C.rowOdd[4])
        row:Show()
    end

    local totalH = math.max(#list * 30, 1)
    listFrame:SetHeight(totalH)

    for i = #list + 1, #listRows do
        listRows[i]:Hide()
        listRows[i]:ClearAllPoints()
    end
end

-- ── Add player row ──────────────────────────────────────────────────────────

local addRow = CreateFrame("Frame", nil, piScrollChild)
addRow:SetHeight(28)
addRow:SetPoint("TOPLEFT",  listScroll, "BOTTOMLEFT",  0, -10)
addRow:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT",  0,  0)

local addBtn = UI:MakeButton(addRow, "Add", function() end, "default")
addBtn:SetSize(70, 26)
addBtn:SetPoint("RIGHT", addRow, "RIGHT", 0, 0)

local addBox = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
addBox:SetSize(220, 24)
addBox:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
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

-- Wire up the Add button now that addBox exists
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

-- ── Alert Settings ──────────────────────────────────────────────────────────

local PI_SyncAlerts  -- forward declaration — assigned after controls are built
local PI_SyncOverlay -- forward declaration — assigned after overlay section is built

local listHint = piScrollChild:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
listHint:SetPoint("TOPLEFT", addRow, "BOTTOMLEFT", 0, -4)
listHint:SetWidth(CONTENT_W - PAD * 2 - 20)
listHint:SetJustifyH("LEFT")
listHint:SetText("Enter character name only \226\128\148 no realm suffix (e.g. \"Playername\", not \"Playername-Realm\").")
listHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local alertLine = UI:MakeLine(piScrollChild, C.border, 1)
alertLine:SetPoint("TOPLEFT",  listHint, "BOTTOMLEFT",  0, -10)
alertLine:SetPoint("TOPRIGHT", piScrollChild, "TOPRIGHT", 0, -10)

local alertSectionHdr = UI:MakeSectionHeader(piScrollChild, alertLine, -8, "Alert Settings")

local alertContent = CreateFrame("Frame", nil, piScrollChild)
alertContent:SetPoint("TOPLEFT",  alertSectionHdr, "BOTTOMLEFT",  0, -8)
alertContent:SetPoint("TOPRIGHT", piScrollChild,   "TOPRIGHT",    0, 0)
alertContent:SetHeight(580)

-- ── Glow section ──────────────────────────────────────────────────────────

local glowSectionLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
glowSectionLabel:SetPoint("TOPLEFT", alertContent, "TOPLEFT", 0, 0)
glowSectionLabel:SetText("Glow")
glowSectionLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

local glowEnableCheck = UI:MakeCheckbox(alertContent, "Enable glow on raid frame", nil, function(val)
    PWT.db.pi.glowEnabled = val
end)
glowEnableCheck:SetPoint("TOPLEFT", glowSectionLabel, "BOTTOMLEFT", 0, -4)
glowEnableCheck:SetPoint("RIGHT",   alertContent, "RIGHT", 0, 0)

local styleLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
styleLabel:SetPoint("TOPLEFT", glowEnableCheck, "BOTTOMLEFT", 22, -6)
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
        local isActive = (btn.styleKey == current)
        UI:StyleButton(btn, isActive)
        btn:SetTextColor(
            isActive and C.textAccent[1] or C.textMuted[1],
            isActive and C.textAccent[2] or C.textMuted[2],
            isActive and C.textAccent[3] or C.textMuted[3])
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
    if UI.StyleSliderThumb then UI:StyleSliderThumb(sl) end
    sl:SetScript("OnValueChanged", onChange)
    row.slider = sl
    return row
end

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
        PWT.db.pi.glowR = nr; PWT.db.pi.glowG = ng; PWT.db.pi.glowB = nb
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

local opacityRow = makeSliderRow(colorRow, "Opacity:", 0.1, 1.0, 0.05, "10%", "100%",
    function(self, val)
        PWT.db.pi.glowOpacity = val
        self.Text:SetText(string.format("%d%%", math.floor(val * 100 + 0.5)))
    end)
local opacitySlider = opacityRow.slider

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
        opacityRow:Hide(); thickRow:Show()
        thickSlider:SetValue(PWT.db.pi.borderThickness or 3)
    else
        thickRow:Hide(); opacityRow:Show()
        opacitySlider:SetValue(PWT.db.pi.glowOpacity or 0.55)
    end
end

local varSpacer = CreateFrame("Frame", nil, alertContent)
varSpacer:SetHeight(46)
varSpacer:SetPoint("TOPLEFT",  colorRow, "BOTTOMLEFT",  0, -10)
varSpacer:SetPoint("TOPRIGHT", alertContent, "TOPRIGHT", 0, -10)

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

local glowTestBtn = UI:MakeButton(alertContent, "Test", function()
    PWT.PI:BuildSoundList()
    local unitToken = "player"
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsUnit("raid"..i, "player") then unitToken = "raid"..i; break end
        end
    end
    local playerName = GetUnitName("player", false) or "preview"
    PWT.PI:ClearGlow(playerName)
    local testFrame = PWT.RaidFrames:Find(unitToken)
    if testFrame then
        PWT.PI:ApplyGlow(testFrame, playerName)
    else
        if PWT.db.pi.soundEnabled ~= false then PWT.PI:PlayCurrentSound() end
        PWT:Print("No raid frame found — sound only. Join a group to test the glow.")
    end
end, "default")
glowTestBtn:SetSize(60, 22)
glowTestBtn:SetPoint("LEFT", pulseSlider, "RIGHT", 10, 0)

local glowResetBtn = UI:MakeButton(alertContent, "Reset Glow", function()
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
end, "default")
glowResetBtn:SetSize(90, 24)
glowResetBtn:SetPoint("TOPLEFT", pulseRow, "BOTTOMLEFT", -22, -10)

-- ── Sound section ─────────────────────────────────────────────────────────

local soundLine = UI:MakeLine(alertContent, C.border, 1)
soundLine:SetPoint("TOPLEFT",  glowResetBtn, "BOTTOMLEFT",  0, -12)
soundLine:SetPoint("TOPRIGHT", alertContent, "TOPRIGHT",    0, -12)

local soundSectionLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
soundSectionLabel:SetPoint("TOPLEFT", soundLine, "BOTTOMLEFT", 0, -8)
soundSectionLabel:SetText("Sound")
soundSectionLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

local soundEnableCheck = UI:MakeCheckbox(alertContent, "Enable alert sound", nil, function(val)
    PWT.db.pi.soundEnabled = val
end)
soundEnableCheck:SetPoint("TOPLEFT", soundSectionLabel, "BOTTOMLEFT", 0, -4)
soundEnableCheck:SetPoint("RIGHT",   alertContent, "RIGHT", 0, 0)

local soundDropLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
soundDropLabel:SetPoint("TOPLEFT", soundEnableCheck, "BOTTOMLEFT", 22, -6)
soundDropLabel:SetText("Sound:")
soundDropLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local soundDd = UI:MakeDropdown(alertContent,
    function()
        PWT.PI:BuildSoundList()
        local list = PWT.PI.soundList or {}
        local result = {}
        for i, entry in ipairs(list) do result[i] = { label = entry.label, value = i } end
        return result
    end,
    function(entry)
        if PWT.db and PWT.db.pi then PWT.db.pi.soundIndex = entry.value end
        local list = PWT.PI.soundList or {}
        local name = (list[entry.value] and list[entry.value].label) or "Unknown"
        if #name > 28 then name = name:sub(1, 25) .. "..." end
        soundDd.setLabel(name)
    end,
    { width=190, popupW=240, popupH=200, rowH=20,
      getSelected = function() return (PWT.db and PWT.db.pi and PWT.db.pi.soundIndex) or 5 end })
soundDd.button:SetPoint("LEFT", soundDropLabel, "RIGHT", 8, 0)

local function UpdateDropLabel()
    local idx  = (PWT.db and PWT.db.pi and PWT.db.pi.soundIndex) or 5
    local list = PWT.PI.soundList or {}
    local name = (list[idx] and list[idx].label) or "Alarm Clock"
    if #name > 28 then name = name:sub(1, 25) .. "..." end
    soundDd.setLabel(name)
end

local soundPreviewBtn = UI:MakeButton(alertContent, "Preview", function()
    PWT.PI:PlayCurrentSound()
end, "default")
soundPreviewBtn:SetSize(60, 22)
soundPreviewBtn:SetPoint("LEFT", soundDd.button, "RIGHT", 6, 0)

local volRow = UI:MakeSlider(alertContent, "Volume:", 0.0, 1.0, 0.05,
    function(val) return string.format("%d%%", math.floor(val * 100 + 0.5)) end,
    function(val) if PWT.db and PWT.db.pi then PWT.db.pi.soundVolume = val end end)
volRow:SetPoint("TOPLEFT", soundDropLabel, "BOTTOMLEFT", 0, -18)
volRow:SetPoint("RIGHT",   alertContent, "RIGHT", 0, 0)

local soundResetBtn = UI:MakeButton(alertContent, "Reset Sound", function()
    PWT.db.pi.soundEnabled = true
    PWT.db.pi.soundIndex   = 5
    PWT.db.pi.soundVolume  = 1.0
    PI_SyncAlerts()
    PWT:Print("Sound settings reset to defaults.")
end, "default")
soundResetBtn:SetSize(100, 24)
soundResetBtn:SetPoint("TOPLEFT", volRow, "BOTTOMLEFT", -22, -10)

-- ── Early Request Grace Period ────────────────────────────────────────────

local earlyLine = UI:MakeLine(alertContent, C.border, 1)
earlyLine:SetPoint("TOPLEFT",  soundResetBtn, "BOTTOMLEFT",  0, -14)
earlyLine:SetPoint("TOPRIGHT", alertContent,  "TOPRIGHT",    0, -14)

local earlySectionLabel = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
earlySectionLabel:SetPoint("TOPLEFT", earlyLine, "BOTTOMLEFT", 0, -8)
earlySectionLabel:SetText("Early Request")
earlySectionLabel:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

local earlyEnableCheck = UI:MakeCheckbox(alertContent, "Alert when PI is almost off cooldown", nil, function(val)
    PWT.db.pi.earlyRequestEnabled = val
end)
earlyEnableCheck:SetPoint("TOPLEFT", earlySectionLabel, "BOTTOMLEFT", 0, -4)
earlyEnableCheck:SetPoint("RIGHT",   alertContent, "RIGHT", 0, 0)

local earlyDesc = alertContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
earlyDesc:SetPoint("TOPLEFT", earlyEnableCheck, "BOTTOMLEFT", 22, -2)
earlyDesc:SetWidth(CONTENT_W - PAD * 2 - 30)
earlyDesc:SetJustifyH("LEFT")
earlyDesc:SetText("When a PI whisper arrives within the grace window before the cooldown expires, trigger the glow and show a countdown overlay.")
earlyDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local earlyWindowRow = makeSliderRow(earlyDesc, "Grace window:", 1, 10, 1, "1s", "10s",
    function(self, val)
        val = math.floor(val + 0.5)
        if PWT.db and PWT.db.pi then PWT.db.pi.earlyRequestWindow = val end
        self.Text:SetText(tostring(val) .. "s")
    end)
local earlyWindowSlider = earlyWindowRow.slider

PI_SyncAlerts = function()
    if not PWT.db or not PWT.db.pi then return end
    local cfg = PWT.db.pi
    glowEnableCheck.set(cfg.glowEnabled ~= false)
    soundEnableCheck.set(cfg.soundEnabled ~= false)
    pulseSlider:SetValue(cfg.glowPulse or 0.6)
    volRow.set(cfg.soundVolume or 1.0)
    PWT.PI:BuildSoundList()
    UpdateDropLabel()
    UpdateStyleButtons()
    colorSwatchTex:SetColorTexture(cfg.glowR or 1, cfg.glowG or 0.85, cfg.glowB or 0, 1.0)
    earlyEnableCheck.set(cfg.earlyRequestEnabled == true)
    earlyWindowSlider:SetValue(cfg.earlyRequestWindow or 5)
    earlyWindowRow.slider.Text:SetText((cfg.earlyRequestWindow or 5) .. "s")
end

-- ── Name Overlay ──────────────────────────────────────────────────────────

local overlayLine = UI:MakeLine(piScrollChild, C.border, 1)
overlayLine:SetPoint("TOPLEFT",  earlyWindowRow, "BOTTOMLEFT", -22, -12)
overlayLine:SetPoint("TOPRIGHT", piScrollChild,  "TOPRIGHT",     0, -12)

local overlaySectionHdr = UI:MakeSectionHeader(piScrollChild, overlayLine, -8, "Name Overlay")

local overlayContent = CreateFrame("Frame", nil, piScrollChild)
overlayContent:SetPoint("TOPLEFT",  overlaySectionHdr, "BOTTOMLEFT",  0, -8)
overlayContent:SetPoint("TOPRIGHT", piScrollChild,     "TOPRIGHT",    0, 0)
overlayContent:SetHeight(140)

local overlayLockBtn
local overlayLocked = true

local overlayEnableCheck = UI:MakeCheckbox(overlayContent, "Show floating name overlay", nil, function(val)
    PWT.db.pi.overlayEnabled = val
    if not val then
        PWT.PI:ForceHideOverlay()
        overlayLockBtn.lbl:SetText("Unlock to Move")
        overlayLockBtn.lbl:SetTextColor(C.text[1], C.text[2], C.text[3])
        overlayLocked = true
    end
end)
overlayEnableCheck:SetPoint("TOPLEFT", overlayContent, "TOPLEFT", 0, 0)
overlayEnableCheck:SetPoint("RIGHT",   overlayContent, "RIGHT",   0, 0)

local overlayEnableDesc = overlayContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
overlayEnableDesc:SetPoint("TOPLEFT", overlayEnableCheck, "BOTTOMLEFT", 22, -2)
overlayEnableDesc:SetWidth(CONTENT_W - PAD * 2 - 30)
overlayEnableDesc:SetJustifyH("LEFT")
overlayEnableDesc:SetText("Displays a floating frame with the PI target's name and spell icon.")
overlayEnableDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local overlaySizeRow = UI:MakeSlider(overlayContent, "Font size:", 10, 48, 1,
    function(val) return tostring(math.floor(val)) .. "px" end,
    function(val)
        if PWT.db and PWT.db.pi then PWT.db.pi.overlayFontSize = math.floor(val) end
        PWT.PI:UpdateOverlayFont()
    end)
overlaySizeRow:SetPoint("TOPLEFT", overlayEnableDesc, "BOTTOMLEFT", 0, -10)
overlaySizeRow:SetPoint("RIGHT",   overlayContent, "RIGHT", 0, 0)

overlayLockBtn = UI:MakeButton(overlayContent, "Unlock to Move", nil, "default")
overlayLockBtn:SetSize(120, 24)
overlayLockBtn:SetPoint("TOPLEFT", overlaySizeRow, "BOTTOMLEFT", 0, -10)
overlayLockBtn:SetScript("OnClick", function()
    if not (PWT.db and PWT.db.pi and PWT.db.pi.overlayEnabled) then
        PWT:Print("Enable the overlay first.")
        return
    end
    overlayLocked = not overlayLocked
    PWT.PI:CreateOverlayWidget()
    if not overlayLocked then
        overlayLockBtn.lbl:SetText("Lock Position")
        overlayLockBtn.lbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
        PWT.PI:SetOverlayMovable(true)
        PWT.PI:ShowOverlay(GetUnitName("player", false) or "Preview")
    else
        overlayLockBtn.lbl:SetText("Unlock to Move")
        overlayLockBtn.lbl:SetTextColor(C.text[1], C.text[2], C.text[3])
        PWT.PI:SetOverlayMovable(false)
        PWT.PI:ForceHideOverlay()
    end
end)

local overlayPreviewBtn = UI:MakeButton(overlayContent, "Preview", function()
    if not (PWT.db and PWT.db.pi and PWT.db.pi.overlayEnabled) then
        PWT:Print("Enable the overlay first.")
        return
    end
    PWT.PI:CreateOverlayWidget()
    PWT.PI:ShowOverlay(GetUnitName("player", false) or "Preview")
    C_Timer.After(5, function()
        if overlayLocked then PWT.PI:ForceHideOverlay() end
    end)
end, "default")
overlayPreviewBtn:SetSize(80, 24)
overlayPreviewBtn:SetPoint("LEFT", overlayLockBtn, "RIGHT", 8, 0)

PI_SyncOverlay = function()
    if not PWT.db or not PWT.db.pi then return end
    overlayEnableCheck.set(PWT.db.pi.overlayEnabled == true)
    overlaySizeRow.set(PWT.db.pi.overlayFontSize or 24)
end

-- Total scroll child height — all sections are always visible
piScrollChild:SetHeight(1000)

-- ── Sync ──────────────────────────────────────────────────────────────────

function UI:SyncPI()
    modePriorityBtn:Show()
    modeSequenceBtn:Show()
    seqIndexLabel:SetShown(PWT.db and PWT.db.piMode == "sequence")
    RefreshList()
    if PWT.db then
        stickLastCheck.set(PWT.db.piSequenceStickLast or false)
        PI_SyncAlerts()
        PI_SyncOverlay()
        UpdateModeButtons()
        UpdateSeqIndexLabel()
    end
end

function UI:DoRefreshPI()
    RefreshList()
    UpdateSeqIndexLabel()
end
