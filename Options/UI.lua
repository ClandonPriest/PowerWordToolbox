-- Power Word: Toolbox | Options/UI.lua

local _, PWT = ...

PWT.UI = {}
local UI = PWT.UI

-- Layout constants (shared by all Options/ files)
UI.FRAME_W   = 840
UI.FRAME_H   = 600
UI.PAD       = 16
UI.TITLE_H   = 36
UI.TAB_BAR_W = 160
UI.FOOTER_H  = 44
UI.CONTENT_W = 648   -- FRAME_W - TAB_BAR_W - PAD*2; accounts for content area inner margins
UI.HEADER_H  = 64            -- height of sidebar logo block and content section header
UI.CONTENT_Y = UI.TITLE_H

-- Colour palette
UI.C = {
    bg              = {0.08, 0.08, 0.10, 0.97},
    titleBar        = {0.10, 0.10, 0.13, 1.00},
    tabBar          = {0.06, 0.06, 0.08, 1.00},
    tabActive       = {0.20, 0.16, 0.08, 1.00},
    tabHover        = {0.14, 0.11, 0.18, 1.00},
    accent          = {0.95, 0.78, 0.15, 1.00},
    accentSecondary = {0.65, 0.45, 0.90, 1.00},
    border          = {0.30, 0.22, 0.42, 0.80},
    rowEven         = {0.11, 0.11, 0.14, 0.80},
    rowOdd          = {0.08, 0.08, 0.10, 0.50},
    footerBg        = {0.06, 0.06, 0.08, 1.00},
    text            = {0.90, 0.88, 0.95, 1.00},
    textMuted       = {0.55, 0.52, 0.60, 1.00},
    textAccent      = {0.95, 0.78, 0.15, 1.00},
    danger          = {0.90, 0.30, 0.30, 1.00},
    success         = {0.30, 0.90, 0.50, 1.00},
}

-- Drawing Helpers
function UI:SetColor(region, c, a)
    region:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
end

function UI:MakeBg(parent, c)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(parent)
    self:SetColor(t, c)
    return t
end

function UI:MakeLine(parent, c, h)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(h or 1)
    self:SetColor(t, c)
    return t
end

-- Font objects (overrideable via General tab font selector)
local PWT_FontLarge  = CreateFont("PWT_FontLarge")
PWT_FontLarge:SetFont("Fonts\\FRIZQT__.TTF", 15, "")
local PWT_FontNormal = CreateFont("PWT_FontNormal")
PWT_FontNormal:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
local PWT_FontSmall  = CreateFont("PWT_FontSmall")
PWT_FontSmall:SetFont("Fonts\\FRIZQT__.TTF", 11, "")

function UI:ApplyFont(path)
    path = path or "Fonts\\FRIZQT__.TTF"
    PWT_FontLarge:SetFont(path, 15, "")
    PWT_FontNormal:SetFont(path, 13, "")
    PWT_FontSmall:SetFont(path, 11, "")
    if PWT.Atonement       then PWT.Atonement:UpdateWidget()      end
    if PWT.PI              then PWT.PI:UpdateOverlayFont()        end
    if PWT.VoidShieldDeck  then PWT.VoidShieldDeck:UpdateWidget() end
end

-- ── Factory Functions ──────────────────────────────────────────────────────

-- Returns frame with .set(bool), .get(), .totalHeight
function UI:MakeCheckbox(parent, text, desc, onChange)
    local C   = self.C
    local rowH = desc and 44 or 24

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(rowH)

    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetSize(16, 16)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
    border:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.9)

    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetSize(12, 12)
    fill:SetPoint("CENTER", border, "CENTER", 0, 0)
    fill:SetColorTexture(0.10, 0.10, 0.13, 1.0)

    local checkmark = frame:CreateTexture(nil, "OVERLAY")
    checkmark:SetSize(14, 14)
    checkmark:SetPoint("CENTER", border, "CENTER", 0, 0)
    checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkmark:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1.0)
    checkmark:Hide()

    local btn = CreateFrame("Button", nil, frame)
    btn:SetHeight(24)
    btn:SetPoint("LEFT",  frame, "LEFT",  0, 0)
    btn:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetPoint("LEFT", border, "RIGHT", 6, 0)
    lbl:SetText(text or "")
    lbl:SetTextColor(C.text[1], C.text[2], C.text[3])

    if desc then
        local d = frame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        d:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -4)
        d:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        d:SetJustifyH("LEFT")
        d:SetText(desc)
        d:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    end

    local checked = false
    local function applyState()
        if checked then
            fill:SetColorTexture(0.10, 0.10, 0.13, 1.0)
            checkmark:Show()
        else
            fill:SetColorTexture(0.10, 0.10, 0.13, 1.0)
            checkmark:Hide()
        end
    end

    btn:SetScript("OnClick", function()
        checked = not checked
        applyState()
        if onChange then onChange(checked) end
    end)

    frame.lbl         = lbl
    frame.totalHeight = rowH
    function frame.set(val) checked = val and true or false; applyState() end
    function frame.get()   return checked end
    return frame
end

function UI:StyleSliderThumb(sl)
    if not sl then return end
    local C = self.C

    local thumb = sl:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(24, 24)
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetVertexColor(1.0, 0.92, 0.45, 1.0)
    sl:SetThumbTexture(thumb)
    sl._pwtThumb = thumb

    local function setThumbState(active, hover)
        if active then
            thumb:SetSize(26, 26)
            thumb:SetVertexColor(1.0, 1.0, 0.65, 1.0)
        elseif hover then
            thumb:SetSize(25, 25)
            thumb:SetVertexColor(1.0, 0.96, 0.55, 1.0)
        else
            thumb:SetSize(24, 24)
            thumb:SetVertexColor(1.0, 0.92, 0.45, 1.0)
        end
    end

    sl:HookScript("OnEnter", function() setThumbState(false, true) end)
    sl:HookScript("OnLeave", function() setThumbState(false, false) end)
    sl:HookScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then setThumbState(true, true) end
    end)
    sl:HookScript("OnMouseUp", function() setThumbState(false, sl:IsMouseOver()) end)
end

-- Returns frame with .set(val), .slider, .totalHeight = 40
function UI:MakeSlider(parent, label, minV, maxV, step, fmt, onChange)
    local C = self.C
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(40)

    local lbl = frame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    lbl:SetText(label or "")
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local valLbl = frame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    valLbl:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    valLbl:SetTextColor(C.text[1], C.text[2], C.text[3])

    local trackBg = frame:CreateTexture(nil, "BACKGROUND")
    trackBg:SetHeight(4)
    trackBg:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -18)
    trackBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -18)
    trackBg:SetColorTexture(0.14, 0.11, 0.18, 1.0)

    local trackFill = frame:CreateTexture(nil, "ARTWORK")
    trackFill:SetHeight(4)
    trackFill:SetPoint("LEFT", trackBg, "LEFT", 0, 0)
    trackFill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.70)
    trackFill:SetWidth(1)

    local sl = CreateFrame("Slider", nil, frame)
    sl:SetHeight(20)
    sl:SetPoint("LEFT",  trackBg, "LEFT",  0, 0)
    sl:SetPoint("RIGHT", trackBg, "RIGHT", 0, 0)
    sl:SetOrientation("HORIZONTAL")
    sl:EnableMouse(true)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)

    self:StyleSliderThumb(sl)

    local lowLbl = frame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lowLbl:SetPoint("TOPLEFT", trackBg, "BOTTOMLEFT", 0, -2)
    lowLbl:SetText(fmt and fmt(minV) or tostring(minV))
    lowLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local highLbl = frame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    highLbl:SetPoint("TOPRIGHT", trackBg, "BOTTOMRIGHT", 0, -2)
    highLbl:SetText(fmt and fmt(maxV) or tostring(maxV))
    highLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local function updateFill(val)
        local w = trackBg:GetWidth()
        if w and w > 0 then
            local ratio = (val - minV) / math.max(maxV - minV, 0.001)
            local thumbW = sl._pwtThumb and sl._pwtThumb:GetWidth() or 0
            local usableW = math.max(1, w - thumbW)
            local fillW = (thumbW / 2) + usableW * math.max(0, math.min(1, ratio))
            trackFill:SetWidth(math.max(1, math.min(w, fillW)))
        end
    end

    sl:SetScript("OnValueChanged", function(self, val)
        valLbl:SetText(fmt and fmt(val) or tostring(val))
        updateFill(val)
        if onChange then onChange(val) end
    end)

    frame.totalHeight = 40
    frame.slider      = sl
    function frame.set(val) sl:SetValue(val) end
    return frame
end

-- Returns Button with .lbl, .bg (border ring), .fill, .SetActive(bool)
function UI:MakeButton(parent, text, onClick, variant)
    local C   = self.C
    local btn = CreateFrame("Button", nil, parent)

    -- bg is the 1px outer ring (border color)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    btn.bg = bg

    -- fill is the inner surface (1px inset from each side)
    local fill = btn:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    btn.fill = fill

    local lbl = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetAllPoints(btn)
    lbl:SetJustifyH("CENTER")
    lbl:SetText(text or "")
    btn.lbl = lbl

    local isDanger = (variant == "danger")
    local isActive = false

    local function applyColors()
        if isActive then
            bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.90)
            fill:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 1.0)
            lbl:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        elseif isDanger then
            bg:SetColorTexture(0.60, 0.25, 0.25, 0.80)
            fill:SetColorTexture(0.12, 0.06, 0.06, 1.0)
            lbl:SetTextColor(C.text[1], C.text[2], C.text[3])
        else
            bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.70)
            fill:SetColorTexture(0.12, 0.10, 0.08, 1.0)
            lbl:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    applyColors()

    btn:SetScript("OnEnter", function()
        if isDanger then
            bg:SetColorTexture(C.danger[1], C.danger[2], C.danger[3], 0.90)
            fill:SetColorTexture(0.25, 0.08, 0.08, 0.9)
        else
            bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.90)
            fill:SetColorTexture(0.22, 0.17, 0.06, 1.0)
        end
    end)
    btn:SetScript("OnLeave", applyColors)
    if onClick then btn:SetScript("OnClick", onClick) end

    function btn:SetActive(val)
        isActive = val and true or false
        applyColors()
    end

    return btn
end

-- Returns frame with .totalHeight = 22; anchored to anchor:BOTTOMLEFT
function UI:MakeSectionHeader(parent, anchor, yOffset, text)
    local C = self.C
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(22)
    frame:SetPoint("TOPLEFT",  anchor, "BOTTOMLEFT",  0, yOffset)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT",    -UI.PAD, 0)

    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetSize(2, 12)
    bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
    bar:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.6)

    local headerLbl = frame:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
    headerLbl:SetPoint("LEFT", bar, "RIGHT", 6, 0)
    headerLbl:SetText(text or "")
    headerLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])

    frame.totalHeight = 22
    return frame
end

-- Returns { button, popup, setLabel(text), refresh() }
-- options: table of {label, value} or a function returning same
-- opts: .width .popupW .popupH .rowH .getSelected .renderRow .onSelect
function UI:MakeDropdown(parent, options, onSelect, opts)
    local C = self.C
    opts = opts or {}
    local btnW        = opts.width       or 180
    local popW        = opts.popupW      or 220
    local popH        = opts.popupH      or 200
    local rowH        = opts.rowH        or 20
    local getSelected = opts.getSelected
    local renderRow   = opts.renderRow

    -- Button
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(btnW, 24)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints(btn)
    btnBg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.70)

    local btnFill = btn:CreateTexture(nil, "ARTWORK")
    btnFill:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
    btnFill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    btnFill:SetColorTexture(0.12, 0.10, 0.08, 1.0)

    local btnLbl = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    btnLbl:SetPoint("LEFT",  btn, "LEFT",  8, 0)
    btnLbl:SetPoint("RIGHT", btn, "RIGHT", -16, 0)
    btnLbl:SetJustifyH("LEFT")
    btnLbl:SetTextColor(C.text[1], C.text[2], C.text[3])

    local arrow = btn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrow:SetText("v")
    arrow:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    btn:SetScript("OnEnter", function()
        btnBg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.90)
        btnFill:SetColorTexture(0.22, 0.17, 0.06, 1.0)
    end)
    btn:SetScript("OnLeave", function()
        btnBg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.70)
        btnFill:SetColorTexture(0.12, 0.10, 0.08, 1.0)
    end)

    -- Popup
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetSize(popW, popH)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(100)
    popup:Hide()
    UI:MakeBg(popup, {0.06, 0.06, 0.08, 0.98})

    local function addBorderLine(p1, rp)
        local t = popup:CreateTexture(nil, "OVERLAY")
        t:SetHeight(1)
        t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
        t:SetPoint(p1, popup, rp, 0, 0)
        t:SetPoint(p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT",
                   popup, p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
    end
    addBorderLine("TOPLEFT",    "TOPLEFT")
    addBorderLine("BOTTOMLEFT", "BOTTOMLEFT")

    local rowW = popW - 4
    local scrollFrame = CreateFrame("ScrollFrame", nil, popup)
    scrollFrame:SetPoint("TOPLEFT",     popup, "TOPLEFT",     2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -2,  2)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * rowH)))
    end)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetWidth(rowW)
    child:SetHeight(1)
    scrollFrame:SetScrollChild(child)

    local rows = {}

    local function hidePopup()
        popup:Hide()
        if UI._activeDropdown == popup then UI._activeDropdown = nil end
    end

    local function populatePopup()
        for _, r in ipairs(rows) do r:Hide() end
        wipe(rows)

        local list = type(options) == "function" and options() or options
        local currentVal = getSelected and getSelected() or nil

        for i, entry in ipairs(list) do
            local row = CreateFrame("Button", nil, child)
            row:SetSize(rowW, rowH)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * rowH)

            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints(row)
            row.bg = rowBg

            if renderRow then
                renderRow(row, entry, entry.value == currentVal)
            else
                local rowLbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
                rowLbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
                rowLbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                rowLbl:SetJustifyH("LEFT")
                rowLbl:SetText(entry.label or tostring(entry.value))

                local isSel = (entry.value == currentVal)
                rowBg:SetColorTexture(
                    isSel and C.tabActive[1] or 0, isSel and C.tabActive[2] or 0,
                    isSel and C.tabActive[3] or 0, isSel and C.tabActive[4] or 0)
                rowLbl:SetTextColor(
                    isSel and C.textAccent[1] or C.text[1],
                    isSel and C.textAccent[2] or C.text[2],
                    isSel and C.textAccent[3] or C.text[3])

                row:SetScript("OnEnter", function(self)
                    local cur = getSelected and getSelected()
                    if entry.value ~= cur then
                        self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6)
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    local cur = getSelected and getSelected()
                    local active = (entry.value == cur)
                    self.bg:SetColorTexture(
                        active and C.tabActive[1] or 0, active and C.tabActive[2] or 0,
                        active and C.tabActive[3] or 0, active and C.tabActive[4] or 0)
                end)
            end

            row:SetScript("OnClick", function()
                if onSelect then
                    local ok, err = pcall(onSelect, entry)
                    if not ok then
                        PWT:Debug("Dropdown selection callback failed: " .. tostring(err), "ui")
                    end
                end
                btnLbl:SetText(entry.label or tostring(entry.value or ""))
                hidePopup()
            end)
            row:Show()
            rows[i] = row
        end

        local totalH = #list * rowH
        child:SetHeight(math.max(totalH, 1))

        if getSelected then
            local curVal = getSelected()
            local list2  = type(options) == "function" and options() or options
            for i, entry in ipairs(list2) do
                if entry.value == curVal then
                    local scrollMax = math.max(0, totalH - popH + 4)
                    scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollMax, (i-1)*rowH - popH/2)))
                    break
                end
            end
        end
    end

    btn:SetScript("OnClick", function()
        if popup:IsShown() then hidePopup(); return end
        if UI._activeDropdown and UI._activeDropdown ~= popup then
            UI._activeDropdown:Hide()
        end
        UI._activeDropdown = popup
        populatePopup()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        popup:Show()
    end)

    local watcher = CreateFrame("Frame", nil, UIParent)
    watcher:SetAllPoints(UIParent)
    watcher:SetFrameStrata("DIALOG")
    watcher:EnableMouse(false)
    watcher:Hide()
    popup:HookScript("OnShow", function()
        watcher:EnableMouse(true)
        watcher:Show()
        watcher:SetScript("OnMouseDown", function(self)
            hidePopup(); self:EnableMouse(false); self:Hide()
        end)
    end)
    popup:HookScript("OnHide", function()
        watcher:EnableMouse(false); watcher:Hide()
    end)

    return {
        button   = btn,
        popup    = popup,
        setLabel = function(t) btnLbl:SetText(t or "") end,
        refresh  = function() if popup:IsShown() then populatePopup() end end,
    }
end

-- Returns an InputBoxTemplate EditBox sized 50×20 with clamp + revert
function UI:MakeFontSizeBox(parent, minV, maxV, onApply)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(50, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    local function apply(self)
        local v = tonumber(self:GetText())
        if v then
            v = math.max(minV, math.min(maxV, v))
            self:SetText(tostring(v))
            if onApply then onApply(v) end
        end
    end
    box:SetScript("OnEnterPressed", function(self) apply(self); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", apply)
    return box
end

-- Returns frame with .lockBtn, .resetBtn, .setLocked(bool), .totalHeight = 24
function UI:MakeLockResetRow(parent, onLock, onUnlock, onReset, lockedLabel, unlockedLabel)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    local lockBtn = UI:MakeButton(frame, lockedLabel or "Unlock to Move", nil, "default")
    lockBtn:SetSize(130, 24)
    lockBtn:SetPoint("LEFT", frame, "LEFT", 0, 0)

    local resetBtn = UI:MakeButton(frame, "Reset Position", nil, "default")
    resetBtn:SetSize(110, 24)
    resetBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)

    local locked = true

    lockBtn:SetScript("OnClick", function()
        locked = not locked
        if locked then
            lockBtn.lbl:SetText(lockedLabel or "Unlock to Move")
            lockBtn:SetActive(false)
            if onLock then onLock() end
        else
            lockBtn.lbl:SetText(unlockedLabel or "Lock Position")
            lockBtn:SetActive(true)
            if onUnlock then onUnlock() end
        end
    end)
    resetBtn:SetScript("OnClick", function()
        if onReset then onReset() end
    end)

    frame.lockBtn     = lockBtn
    frame.resetBtn    = resetBtn
    frame.totalHeight = 24

    function frame.setLocked(val)
        locked = val and true or false
        if locked then
            lockBtn.lbl:SetText(lockedLabel or "Unlock to Move")
            lockBtn:SetActive(false)
        else
            lockBtn.lbl:SetText(unlockedLabel or "Lock Position")
            lockBtn:SetActive(true)
        end
    end

    return frame
end

-- Lightweight helper for hand-built buttons with btn.bg texture
function UI:StyleButton(btn, isActive)
    local C = self.C
    if isActive then
        btn.bg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.9)
    else
        btn.bg:SetColorTexture(0.10, 0.10, 0.12, 0.85)
    end
end

-- ── Tab System ─────────────────────────────────────────────────────────────

local tabDisabledState = {}
local tabs      = {}
local tabPanels = {}
local activeTab = nil
UI.tabs      = tabs
UI.tabPanels = tabPanels

local TAB_H = 44

local TAB_META = {
    general    = { title = "General",           desc = "Enable modules and configure fonts and audio settings." },
    pi         = { title = "Power Infusion",    desc = "Tracks PI requests from group whispers and highlights the target on your raid frames." },
    atonement  = { title = "Atonement Tracker", desc = "Displays active Atonement count and lowest timer as a moveable widget." },
    radiance   = { title = "Radiance Bars",     desc = "Two charge bars that fill as Radiance comes off cooldown." },
    voidshield = { title = "Void Shield Deck",  desc = "Tracks your 3-card Void Shield deck and alerts you when the proc card is drawn." },
}

-- Built-in WoW spell icons — no custom assets needed.
-- C_Spell.GetSpellTexture returns a numeric fileID usable with SetTexture.
local function SpellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture(id) or nil
end
local TAB_ICONS = {
    general    = "Interface\\Icons\\Spell_Holy_WordFortitude",  -- PW:Fortitude, classic priest icon
    pi         = SpellIcon(10060),   -- Power Infusion
    atonement  = SpellIcon(194384),  -- Atonement
    radiance   = SpellIcon(194509),  -- Power Word: Radiance
    voidshield = 7514191,            -- Void Shield (file ID)
}

local function SwitchTab(name)
    if tabDisabledState[name] then return end
    activeTab = name
    local C = UI.C

    local meta = TAB_META[name]
    if meta and UI.contentHeaderTitle then
        UI.contentHeaderTitle:SetText(meta.title)
        UI.contentHeaderDesc:SetText(meta.desc)
    end

    if UI.piFooterControls then UI.piFooterControls:Hide() end
    if UI.modePriorityBtn  then UI.modePriorityBtn:Hide()  end
    if UI.modeSequenceBtn  then UI.modeSequenceBtn:Hide()  end
    if UI.seqIndexLabel    then UI.seqIndexLabel:Hide()    end

    for tabName, tab in pairs(tabs) do
        local isActive = (tabName == name)
        if isActive then
            tab.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.70)
            if tab.fill  then tab.fill:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 1.0) end
            if tab.icon  then tab.icon:SetVertexColor(C.textAccent[1], C.textAccent[2], C.textAccent[3]) end
            tab.label:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            tab.accent:Show()
        elseif not tabDisabledState[tabName] then
            tab.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)
            if tab.fill  then tab.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75) end
            if tab.icon  then tab.icon:SetVertexColor(0.78, 0.75, 0.85) end
            tab.label:SetTextColor(0.78, 0.75, 0.85, 1.0)
            tab.accent:Hide()
        end
        tab:EnableMouse(not tabDisabledState[tabName])
    end
    for panelName, panel in pairs(tabPanels) do
        if panelName == name then panel:Show() else panel:Hide() end
    end

    if name == "general"    and UI.SyncGeneral    then UI:SyncGeneral()    end
    if name == "pi"         and UI.SyncPI         then UI:SyncPI()         end
    if name == "atonement"  and UI.SyncAtonement  then UI:SyncAtonement()  end
    if name == "radiance"   and UI.SyncRadiance   then UI:SyncRadiance()   end
    if name == "voidshield" and UI.SyncVoidShield then UI:SyncVoidShield() end
end
UI.SwitchTab = SwitchTab

function UI:AddTab(name, label, index)
    local C  = self.C
    local tab = CreateFrame("Button", nil, self.tabBar)
    tab:SetHeight(TAB_H)
    tab:SetPoint("TOPLEFT",  self.tabBar, "TOPLEFT",  0, -(index - 1) * TAB_H)
    tab:SetPoint("TOPRIGHT", self.tabBar, "TOPRIGHT", 0, -(index - 1) * TAB_H)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints(tab)
    tab.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)

    tab.fill = tab:CreateTexture(nil, "ARTWORK")
    tab.fill:SetPoint("TOPLEFT",     tab, "TOPLEFT",     1, -1)
    tab.fill:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
    tab.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75)

    -- Left-edge accent bar (gold, 2px wide, 2px inset top/bottom)
    tab.accent = tab:CreateTexture(nil, "OVERLAY")
    tab.accent:SetWidth(2)
    tab.accent:SetPoint("TOPLEFT",    tab, "TOPLEFT",    0,  2)
    tab.accent:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, -2)
    tab.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    tab.accent:Hide()

    -- Icon (uses built-in WoW spell icons — no custom assets)
    local iconTex = TAB_ICONS[name]
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(20, 20)
    tab.icon:SetPoint("LEFT", tab, "LEFT", 10, 0)
    if iconTex then
        tab.icon:SetTexture(iconTex)
        tab.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- trim the standard icon border
    else
        tab.icon:Hide()
    end

    tab.label = tab:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
    tab.label:SetPoint("LEFT", iconTex and tab.icon or tab, iconTex and "RIGHT" or "LEFT",
                       iconTex and 7 or 12, 0)
    tab.label:SetText(label)
    tab.label:SetTextColor(0.78, 0.75, 0.85, 1.0)

    tab:SetScript("OnClick", function()
        PWT:Debug("Tab clicked: " .. name .. "  disabled=" .. tostring(tabDisabledState[name]))
        SwitchTab(name)
    end)
    tab:SetScript("OnEnter", function(self)
        if tabDisabledState[name] then return end
        if activeTab ~= name then
            self.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.55)
            self.fill:SetColorTexture(0.20, 0.15, 0.26, 0.85)
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if tabDisabledState[name] then return end
        if activeTab ~= name then
            self.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)
            self.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75)
            self.label:SetTextColor(0.78, 0.75, 0.85, 1.0)
        end
    end)

    tab:RegisterForClicks("LeftButtonUp")
    tab:EnableMouse(true)

    local panel = CreateFrame("Frame", nil, self.contentArea)
    panel:SetAllPoints(self.contentArea)
    panel:Hide()

    tabs[name]      = tab
    tabPanels[name] = panel
    return panel
end

function UI:SetTabEnabled(name, enabled)
    local tab = tabs[name]
    if not tab then return end
    PWT:Debug("SetTabEnabled: " .. name .. " -> " .. tostring(enabled))
    local C = UI.C
    tabDisabledState[name] = not enabled
    if enabled then
        tab:EnableMouse(true)
        tab:SetAlpha(1.0)
        tab.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.30)
        if tab.fill then tab.fill:SetColorTexture(0.13, 0.10, 0.17, 0.75) end
        if tab.icon then tab.icon:SetVertexColor(0.78, 0.75, 0.85) end
        tab.label:SetTextColor(0.78, 0.75, 0.85, 1.0)
        tab.accent:Hide()
        if activeTab == name then
            tab.bg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.70)
            if tab.fill then tab.fill:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 1.0) end
            if tab.icon then tab.icon:SetVertexColor(C.textAccent[1], C.textAccent[2], C.textAccent[3]) end
            tab.label:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            tab.accent:Show()
        end
    else
        tab:EnableMouse(false)
        tab:SetAlpha(0.65)
        tab.bg:SetColorTexture(0.08, 0.04, 0.04, 1.0)
        if tab.fill then tab.fill:SetColorTexture(0.05, 0.02, 0.02, 1.0) end
        if tab.icon then tab.icon:SetVertexColor(0.45, 0.15, 0.15) end
        tab.label:SetTextColor(C.danger[1] * 0.5, C.danger[2] * 0.5, C.danger[3] * 0.5, 1.0)
        tab.accent:Hide()
        if activeTab == name then
            SwitchTab("general")
        end
    end
end

function UI:RefreshTabStates()
    if not PWT.db then return end
    PWT:Debug("RefreshTabStates called")
    UI:SetTabEnabled("pi",         PWT.db.piEnabled)
    UI:SetTabEnabled("atonement",  PWT.db.atonement     and PWT.db.atonement.enabled     or false)
    UI:SetTabEnabled("radiance",   PWT.db.radiance       and PWT.db.radiance.enabled       or false)
    UI:SetTabEnabled("voidshield", PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled or false)
end

function UI:UpdateTabVisibility()
    if tabs["pi"]         then tabs["pi"]:SetShown(PWT.isPriest)  end
    if tabs["atonement"]  then tabs["atonement"]:SetShown(PWT.isDisc)  end
    if tabs["radiance"]   then tabs["radiance"]:SetShown(PWT.isDisc)   end
    if tabs["voidshield"] then tabs["voidshield"]:SetShown(PWT.isDisc) end
end

-- ── Window Construction ────────────────────────────────────────────────────

local optionsFrame = CreateFrame("Frame", "PowerWordToolboxOptions", UIParent)
UI.optionsFrame = optionsFrame

local C             = UI.C
local PAD           = UI.PAD
local HEADER_H      = UI.HEADER_H
local FOOTER_H      = UI.FOOTER_H
local FRAME_W       = UI.FRAME_W
local FRAME_H       = UI.FRAME_H
local TAB_BAR_W_val = UI.TAB_BAR_W

optionsFrame:SetPoint("CENTER")
table.insert(UISpecialFrames, "PowerWordToolboxOptions")
optionsFrame:SetMovable(true)
optionsFrame:SetClampedToScreen(true)
optionsFrame:EnableMouse(true)
local function AttachOptionsDrag(region)
    region:SetScript("OnMouseDown", function(self, btn)
        if UI._activeDropdown then UI._activeDropdown:Hide() end
        if btn ~= "LeftButton" then return end
        local startX, startY = GetCursorPosition()
        local dragging = false

        self:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                if dragging then optionsFrame:StopMovingOrSizing() end
                self:SetScript("OnUpdate", nil)
                return
            end

            local x, y = GetCursorPosition()
            local dx, dy = x - startX, y - startY
            if not dragging and (dx * dx + dy * dy) >= 16 then
                dragging = true
                optionsFrame:StartMoving()
            end
        end)
    end)
    region:SetScript("OnMouseUp", function(self)
        optionsFrame:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
    end)
end

AttachOptionsDrag(optionsFrame)
optionsFrame:SetFrameStrata("DIALOG")
optionsFrame:SetResizable(true)
optionsFrame:SetResizeBounds(600, 500)
PWT:Debug("UI.FRAME_W at creation: " .. tostring(UI.FRAME_W) .. ", FRAME_W local: " .. tostring(FRAME_W))
optionsFrame:SetSize(FRAME_W, FRAME_H)
PWT:Debug("Options frame after SetSize: " .. optionsFrame:GetWidth() .. "x" .. optionsFrame:GetHeight())
optionsFrame:Hide()

-- Resize grip
local resizeGrip = CreateFrame("Button", nil, UIParent)
resizeGrip:SetSize(18, 18)
resizeGrip:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetFrameStrata("DIALOG")
resizeGrip:SetFrameLevel(optionsFrame:GetFrameLevel() + 50)
resizeGrip:CreateTexture(nil, "OVERLAY"):SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
local rgh = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
rgh:SetAllPoints(resizeGrip)
rgh:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetScript("OnMouseDown", function(self, btn)
    if btn == "LeftButton" then
        local x = optionsFrame:GetLeft()
        local y = optionsFrame:GetTop()
        optionsFrame:ClearAllPoints()
        optionsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        optionsFrame:StartSizing("BOTTOMRIGHT")
    end
end)
resizeGrip:SetScript("OnMouseUp", function() optionsFrame:StopMovingOrSizing() end)
optionsFrame:HookScript("OnHide", function() resizeGrip:Hide() end)
optionsFrame:HookScript("OnShow", function() resizeGrip:Show() end)
resizeGrip:Hide()
resizeGrip:SetScript("OnEnter", function()
    GameTooltip:SetOwner(resizeGrip, "ANCHOR_LEFT")
    GameTooltip:SetText("Drag to resize")
    GameTooltip:Show()
end)
resizeGrip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Backgrounds / borders
UI:MakeBg(optionsFrame, C.bg)
local bTop = UI:MakeLine(optionsFrame, C.border, 1)
bTop:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, 0)
bTop:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, 0)
local bBot = UI:MakeLine(optionsFrame, C.border, 1)
bBot:SetPoint("BOTTOMLEFT",  optionsFrame, "BOTTOMLEFT",  0, 0)
bBot:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", 0, 0)

-- ── Sidebar logo header ────────────────────────────────────────────────────

local sidebarHeader = CreateFrame("Frame", nil, optionsFrame)
sidebarHeader:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 0, 0)
sidebarHeader:SetWidth(TAB_BAR_W_val)
sidebarHeader:SetHeight(HEADER_H)
UI:MakeBg(sidebarHeader, C.titleBar)
sidebarHeader:EnableMouse(true)
AttachOptionsDrag(sidebarHeader)

local logo = sidebarHeader:CreateTexture(nil, "ARTWORK")
logo:SetSize(40, 40)
logo:SetPoint("LEFT", sidebarHeader, "LEFT", 10, 0)
logo:SetTexture("Interface\\AddOns\\PowerWordToolbox\\Media\\logo.png")

local sidebarName = sidebarHeader:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
sidebarName:SetPoint("LEFT", logo, "RIGHT", 8, 0)
sidebarName:SetPoint("RIGHT", sidebarHeader, "RIGHT", -4, 0)
sidebarName:SetText("|cffcc99ffPower Word:|r\nToolbox")
sidebarName:SetTextColor(C.text[1], C.text[2], C.text[3])

-- Separator at bottom of sidebar header to distinguish it from the tab list
local sidebarHeaderLine = sidebarHeader:CreateTexture(nil, "ARTWORK")
sidebarHeaderLine:SetHeight(1)
sidebarHeaderLine:SetPoint("BOTTOMLEFT",  sidebarHeader, "BOTTOMLEFT",  0, 0)
sidebarHeaderLine:SetPoint("BOTTOMRIGHT", sidebarHeader, "BOTTOMRIGHT", 0, 0)
sidebarHeaderLine:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.6)

-- ── Content section header ─────────────────────────────────────────────────

local contentHeader = CreateFrame("Frame", nil, optionsFrame)
contentHeader:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  TAB_BAR_W_val, 0)
contentHeader:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, 0)
contentHeader:SetHeight(HEADER_H)
UI:MakeBg(contentHeader, C.titleBar)

-- Vertical separator at the left edge of the content header (sidebar ↔ content header)
local headerVSep = contentHeader:CreateTexture(nil, "ARTWORK")
headerVSep:SetWidth(1)
headerVSep:SetPoint("TOPLEFT",    contentHeader, "TOPLEFT",    0, 0)
headerVSep:SetPoint("BOTTOMLEFT", contentHeader, "BOTTOMLEFT", 0, 0)
headerVSep:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.6)
contentHeader:EnableMouse(true)
AttachOptionsDrag(contentHeader)

local closeBtn = CreateFrame("Button", nil, optionsFrame)
closeBtn:SetSize(28, 28)
closeBtn:SetPoint("RIGHT", contentHeader, "RIGHT", -4, 0)
closeBtn:SetFrameLevel(contentHeader:GetFrameLevel() + 5)

local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
closeBg:SetAllPoints(closeBtn)
closeBg:SetColorTexture(0, 0, 0, 0)

local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
closeLbl:SetAllPoints(closeBtn)
closeLbl:SetJustifyH("CENTER")
closeLbl:SetText("x")
closeLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)
closeBtn:SetScript("OnEnter", function()
    closeBg:SetColorTexture(C.danger[1] * 0.3, 0.05, 0.05, 1.0)
    closeLbl:SetTextColor(C.danger[1], C.danger[2], C.danger[3])
end)
closeBtn:SetScript("OnLeave", function()
    closeBg:SetColorTexture(0, 0, 0, 0)
    closeLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
end)

UI.contentHeaderTitle = contentHeader:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
UI.contentHeaderTitle:SetPoint("LEFT",  contentHeader, "LEFT",  PAD, 8)
UI.contentHeaderTitle:SetPoint("RIGHT", closeBtn,      "LEFT",  -PAD, 0)
UI.contentHeaderTitle:SetJustifyH("CENTER")
UI.contentHeaderTitle:SetTextColor(C.text[1], C.text[2], C.text[3])
UI.contentHeaderTitle:SetText(TAB_META["general"].title)

UI.contentHeaderDesc = contentHeader:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
UI.contentHeaderDesc:SetPoint("LEFT",  contentHeader, "LEFT",  PAD, -10)
UI.contentHeaderDesc:SetPoint("RIGHT", closeBtn,      "LEFT",  -PAD, 0)
UI.contentHeaderDesc:SetJustifyH("CENTER")
UI.contentHeaderDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
UI.contentHeaderDesc:SetText(TAB_META["general"].desc)

-- ── Shared dividers ────────────────────────────────────────────────────────

local headerAccent = UI:MakeLine(optionsFrame, C.accent, 2)
headerAccent:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, -HEADER_H)
headerAccent:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, -HEADER_H)

local vSep = optionsFrame:CreateTexture(nil, "ARTWORK")
vSep:SetWidth(1)
vSep:SetPoint("TOPLEFT",    optionsFrame, "TOPLEFT",    TAB_BAR_W_val, 0)
vSep:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", TAB_BAR_W_val, FOOTER_H)
vSep:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])

-- ── Tab bar ────────────────────────────────────────────────────────────────

local tabBar = CreateFrame("Frame", nil, optionsFrame)
tabBar:SetPoint("TOPLEFT",    optionsFrame, "TOPLEFT",    0, -HEADER_H)
tabBar:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 0, FOOTER_H)
tabBar:SetWidth(TAB_BAR_W_val)
UI:MakeBg(tabBar, C.tabBar)
UI.tabBar = tabBar

-- Content area (PAD margin on left and right)
local contentArea = CreateFrame("Frame", nil, optionsFrame)
contentArea:SetPoint("TOPLEFT",     optionsFrame, "TOPLEFT",     TAB_BAR_W_val + PAD, -HEADER_H)
contentArea:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -PAD,                FOOTER_H)
UI.contentArea = contentArea

-- Footer
local footer = CreateFrame("Frame", nil, optionsFrame)
footer:SetPoint("BOTTOMLEFT",  optionsFrame, "BOTTOMLEFT",  0, 0)
footer:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", 0, 0)
footer:SetHeight(FOOTER_H)
UI:MakeBg(footer, C.footerBg)
local footerLine = UI:MakeLine(optionsFrame, C.border, 1)
footerLine:SetPoint("BOTTOMLEFT",  footer, "TOPLEFT",  0, 0)
footerLine:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
UI.footer = footer

local footerVersion = footer:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
footerVersion:SetPoint("RIGHT", footer, "RIGHT", -PAD, 0)
footerVersion:SetText("v" .. (C_AddOns.GetAddOnMetadata("PowerWordToolbox", "Version") or "?"))
footerVersion:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Public API
function UI:Toggle()
    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        if not PWT.isPriest then
            PWT:Print("Power Word: Toolbox is designed for Priests only.")
            return
        end
        local x, y = optionsFrame:GetLeft(), optionsFrame:GetTop()
        if not x or not y or x < 0 or x > UIParent:GetWidth()
                          or y < 0 or y > UIParent:GetHeight() then
            optionsFrame:ClearAllPoints()
            optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        optionsFrame:SetSize(FRAME_W, FRAME_H)
        PWT:Debug("Force options frame size on show: " .. FRAME_W .. "x" .. FRAME_H)
        PWT:Debug("Showing options window, current size: " .. optionsFrame:GetWidth() .. "x" .. optionsFrame:GetHeight())
        optionsFrame:Show()
    end
end

function UI:ResetPosition()
    if UI._activeDropdown then UI._activeDropdown:Hide() end
    optionsFrame:ClearAllPoints()
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    optionsFrame:SetSize(FRAME_W, FRAME_H)
    optionsFrame:Show()
    PWT:Print("Options window reset to center.")
end

function UI:RefreshPI()
    if UI.DoRefreshPI then UI:DoRefreshPI() end
end

optionsFrame:SetScript("OnShow", function()
    if UI.RefreshTabStates then UI:RefreshTabStates() end
    SwitchTab(activeTab or "general")
end)
