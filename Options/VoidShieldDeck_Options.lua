-- Power Word: Toolbox | Options/VoidShieldDeck_Options.lua

local _, PWT = ...
local UI  = PWT.UI
local C   = UI.C
local PAD = UI.PAD
local CONTENT_W = UI.CONTENT_W

local vsPanel = UI:AddTab("voidshield", "Void Shield", 5)

-- Re-sync whenever the panel is shown so saved values are always reflected,
-- regardless of whether SwitchTab had a fully-laid-out frame on first call.
vsPanel:HookScript("OnShow", function()
    C_Timer.After(0, function()
        if UI.SyncVoidShield then UI:SyncVoidShield() end
    end)
end)

local vsScroll = CreateFrame("ScrollFrame", nil, vsPanel)
vsScroll:SetPoint("TOPLEFT",     vsPanel, "TOPLEFT",     0, -2)
vsScroll:SetPoint("BOTTOMRIGHT", vsPanel, "BOTTOMRIGHT", 0,  0)
vsScroll:EnableMouseWheel(true)
vsScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
end)

-- Total pixel height of static content. Update if sections are added/removed.
local VS_CONTENT_H = 1440

local vsContent = CreateFrame("Frame", nil, vsScroll)
vsContent:SetWidth(CONTENT_W)
vsContent:SetHeight(VS_CONTENT_H)
vsScroll:SetScrollChild(vsContent)

-- ── Shared strata options ──────────────────────────────────────────────────

local STRATA_OPTIONS = {
    { label = "BACKGROUND", value = "BACKGROUND" },
    { label = "LOW",        value = "LOW" },
    { label = "MEDIUM",     value = "MEDIUM" },
    { label = "HIGH",       value = "HIGH" },
    { label = "DIALOG",     value = "DIALOG" },
}

-- Creates a "Strata:" label + dropdown row anchored below anchor.
-- Returns the row frame and the dropdown table { button, setLabel, ... }.
local function makeStrataRow(anchor, yOffset, dbKey)
    local row = CreateFrame("Frame", nil, vsContent)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT",  anchor,    "BOTTOMLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", vsContent, "TOPRIGHT", -PAD, 0)

    local lbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 2)
    lbl:SetText("Strata:")
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local dd = UI:MakeDropdown(row, STRATA_OPTIONS, function(entry)
        if PWT.db and PWT.db.voidShieldDeck then
            PWT.db.voidShieldDeck[dbKey] = entry.value
        end
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:ApplyStrata() end
        dd.setLabel(entry.value)
    end, {
        width       = 130,
        popupW      = 152,
        popupH      = #STRATA_OPTIONS * 20 + 4,
        rowH        = 20,
        getSelected = function()
            return (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck[dbKey]) or "MEDIUM"
        end,
    })
    dd.button:SetPoint("LEFT", lbl, "RIGHT", 8, 0)

    return row, dd
end

-- Creates a "Font size:" label + edit box row anchored below anchor.
-- Returns the row frame and the edit box.
local function makeFontRow(anchor, yOffset, dbKey, defaultVal)
    local row = CreateFrame("Frame", nil, vsContent)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT",  anchor,    "BOTTOMLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", vsContent, "TOPRIGHT", -PAD, 0)

    local lbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 2)
    lbl:SetText("Font size:")
    lbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local box = UI:MakeFontSizeBox(row, 10, 40, function(v)
        if PWT.db and PWT.db.voidShieldDeck then
            PWT.db.voidShieldDeck[dbKey] = v
        end
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
    end)
    box:SetPoint("LEFT", lbl, "RIGHT", 8, 0)

    local hint = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 6, 2)
    hint:SetText("(10–40)")
    hint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    box:SetText(tostring(defaultVal or 18))
    return row, box
end

local function makeCardColorPicker(anchor, xOffset, labelText, dbKey, fallback)
    local frame = CreateFrame("Frame", nil, vsContent)
    frame:SetSize(70, 42)
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, -10)

    local label = frame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(C.text[1], C.text[2], C.text[3])

    local swatch = CreateFrame("Button", nil, frame)
    swatch:SetSize(22, 22)
    swatch:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)

    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(swatch)
    border:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.8)

    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1, 1)

    local function getColor()
        local col = PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck[dbKey]
        col = col or fallback
        return col[1] or fallback[1], col[2] or fallback[2], col[3] or fallback[3]
    end

    local function setColor(r, g, b) fill:SetColorTexture(r, g, b, 1) end

    local function applyColor(r, g, b)
        if PWT.db and PWT.db.voidShieldDeck then
            PWT.db.voidShieldDeck[dbKey] = {r, g, b}
        end
        setColor(r, g, b)
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
    end

    swatch:SetScript("OnClick", function()
        local r, g, b = getColor()
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b, hasOpacity = false,
                swatchFunc = function() applyColor(ColorPickerFrame:GetColorRGB()) end,
                cancelFunc = function(prev) applyColor(prev.r, prev.g, prev.b) end,
            })
        else
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.func = function() applyColor(ColorPickerFrame:GetColorRGB()) end
            ColorPickerFrame.cancelFunc = function() applyColor(r, g, b) end
            ColorPickerFrame.hasOpacity = false
            ShowUIPanel(ColorPickerFrame)
        end
    end)
    swatch:SetScript("OnEnter", function()
        border:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1.0)
        GameTooltip:SetOwner(swatch, "ANCHOR_RIGHT")
        GameTooltip:SetText(labelText .. " color")
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function()
        border:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.8)
        GameTooltip:Hide()
    end)

    function frame.set(r, g, b) setColor(r, g, b) end
    local r, g, b = getColor()
    setColor(r, g, b)
    return frame
end

local voidShieldGuide = nil
local function ApplyGuideCardColor(card, kind)
    if kind == "-->" then
        card:SetColorTexture(0, 0, 0, 0)
        if card.arrow then
            card.arrow:Hide()
        end
        if not card.arrowText then
            local arrowText = card:GetParent():CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
            arrowText:SetPoint("CENTER", card, "CENTER", 0, 0)
            arrowText:SetText("->")
            arrowText:SetTextColor(1, 1, 1, 1)
            card.arrowText = arrowText
        else
            card.arrowText:Show()
        end
        return
    end

    if card.arrowText then
        card.arrowText:Hide()
    end
    if card.arrow then
        card.arrow:Hide()
    end

    if PWT.VoidShieldDeck and PWT.VoidShieldDeck.GetCardColor then
        card:SetColorTexture(PWT.VoidShieldDeck:GetCardColor(kind))
    elseif kind == "proc" then
        card:SetColorTexture(0.15, 0.75, 0.25, 1)
    elseif kind == "unknown" then
        card:SetColorTexture(0.55, 0.52, 0.60, 1)
    else
        card:SetColorTexture(0.80, 0.15, 0.15, 1)
    end
end

local function RefreshVoidShieldGuideColors()
    if not voidShieldGuide or not voidShieldGuide.cards then return end
    for _, card in ipairs(voidShieldGuide.cards) do
        ApplyGuideCardColor(card.texture, card.kind)
    end
end

function UI:ShowVoidShieldGuide()
    if voidShieldGuide then
        RefreshVoidShieldGuideColors()
        voidShieldGuide:Show()
        voidShieldGuide:SetFrameLevel((UI.optionsFrame and UI.optionsFrame:GetFrameLevel() or 100) + 20)
        return
    end

    local f = CreateFrame("Frame", "PWT_VoidShieldGuide", UIParent)
    voidShieldGuide = f
    f.cards = {}
    f:SetSize(560, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel((UI.optionsFrame and UI.optionsFrame:GetFrameLevel() or 100) + 20)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    UI:MakeBg(f, C.bg)

    local top = UI:MakeLine(f, C.border, 1)
    top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    local bottom = UI:MakeLine(f, C.border, 1)
    bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    header:SetHeight(48)
    UI:MakeBg(header, C.titleBar)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local title = header:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
    title:SetPoint("LEFT", header, "LEFT", 16, 0)
    title:SetText("Void Shield Deck Guide")
    title:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

    local closeBtn = UI:MakeButton(header, "x", function() f:Hide() end, "default")
    closeBtn:SetSize(28, 24)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -10, 0)

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 16, -14)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(520)
    content:SetHeight(760)
    scroll:SetScrollChild(content)

    local function addText(anchor, yOffset, text, large)
        local fs = content:CreateFontString(nil, "OVERLAY", large and "PWT_FontNormal" or "PWT_FontSmall")
        fs:SetPoint("TOPLEFT", anchor, anchor == content and "TOPLEFT" or "BOTTOMLEFT", 0, yOffset)
        fs:SetWidth(520)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(
            large and C.textAccent[1] or C.text[1],
            large and C.textAccent[2] or C.text[2],
            large and C.textAccent[3] or C.text[3])
        return fs
    end

    local intro = addText(content, 0,
        "Void Shield uses a 3-card deck: one proc card and two no-proc cards. Each Penance cast draws exactly one card from the current deck.", true)

    local function makeExample(anchor, yOffset, labelText, cards)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(520, 46)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)

        local label = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetWidth(210)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)
        label:SetTextColor(C.text[1], C.text[2], C.text[3])

        for i, kind in ipairs(cards) do
            local card = row:CreateTexture(nil, "ARTWORK")
            card:SetSize(28, 38)
            card:SetPoint("LEFT", row, "LEFT", 230 + (i - 1) * 36, 0)
            ApplyGuideCardColor(card, kind)
            f.cards[#f.cards + 1] = { texture = card, kind = kind }
        end

        return row
    end

    local ex1 = makeExample(intro, -18, "Fresh deck: 33% proc chance", {"proc", "noProc", "noProc"})
    local ex2 = makeExample(ex1, -8, "One no-proc drawn: 50%", {"proc", "noProc"})
    local ex3 = makeExample(ex2, -8, "Two no-procs drawn: 100%", {"proc"})
    local ex4 = makeExample(ex3, -8, "Proc already drawn: 0%", {"noProc", "noProc"})

    local bestLuck = addText(ex4, -18,
        "The most in a row procs you can get is two back-to-back. This occurs when you have the last card in deck 1 be the proc and the first card in deck two be the proc.", true)

    local ex5 = makeExample(bestLuck, -18, "Two back to back procs", {"noProc", "noProc", "proc", "-->", "proc", "noProc", "noProc"})

    local worstLuck = addText(ex5, -18,
        "The worst-case scenario is drawing 4 no-procs in a row. This occurs when you have the first card in deck 1 be the proc and the last card of deck 2 be the proc leaving 4 no procs in a row in the middle.", true)

    local ex6 = makeExample(worstLuck, -18, "Four no-procs in a row", {"proc", "noProc", "noProc", "-->", "noProc", "noProc", "proc"})

    local unknownHint = addText(ex6, -16,
        "The tracker will attempt to determine the current deck status. In any situation where the tracker has either lost its place or has identified an improper state, the cards will show as unknown until it has an opportunity to resync itself.", false)
    unknownHint:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])

    local unknownState = makeExample(unknownHint, -16, "Currently Unknown deck state", {"unknown", "unknown", "unknown"})

    local notes = addText(unknownState, -16,
        "The deck resets on 3 conditions; When all 3 cards have been drawn, when a raid boss starts, or when the Mythic+ timer begins.\n\n" ..
        "The addon detects a proc by watching the Power Word: Shield action bar texture after Penance. Power Word: Shield must stay on an action bar for tracking to remain accurate.", false)
    notes:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
end

-- ── Intro / How It Works ──────────────────────────────────────────────────

local vsIntroToggleBtn = CreateFrame("Button", nil, vsContent)
vsIntroToggleBtn:SetSize(72, 18)
vsIntroToggleBtn:SetPoint("TOPRIGHT", vsContent, "TOPRIGHT", -PAD, -PAD)

local vsToggleBg = vsIntroToggleBtn:CreateTexture(nil, "BACKGROUND")
vsToggleBg:SetAllPoints(vsIntroToggleBtn)
vsToggleBg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.15)

-- Arrow icon: a right-pointing triangle rotated 90° CW for "down" (expanded)
local vsToggleArrow = vsIntroToggleBtn:CreateTexture(nil, "ARTWORK")
vsToggleArrow:SetSize(10, 10)
vsToggleArrow:SetPoint("LEFT", vsIntroToggleBtn, "LEFT", 6, 0)
vsToggleArrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")

local vsToggleLbl = vsIntroToggleBtn:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
vsToggleLbl:SetPoint("LEFT",  vsToggleArrow, "RIGHT", 4, 0)
vsToggleLbl:SetPoint("RIGHT", vsIntroToggleBtn, "RIGHT", -4, 0)
vsToggleLbl:SetJustifyH("LEFT")
vsToggleLbl:SetText("Details")
vsToggleLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local vsIntroSummary = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
vsIntroSummary:SetPoint("TOPLEFT", vsContent, "TOPLEFT", 0, -PAD)
vsIntroSummary:SetPoint("RIGHT", vsIntroToggleBtn, "LEFT", -8, 0)
vsIntroSummary:SetJustifyH("LEFT")
vsIntroSummary:SetText("Void Shield operates on a 3-card deck mechanic. By tracking this deck, you can better understand the exact percent chance to proc on each Penance cast. Click Details for a full guide.")
vsIntroSummary:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local vsIntroLine = UI:MakeLine(vsContent, C.border, 1)

local vsIntroExpanded = { Show = function() end, Hide = function() end }
local vsExpanded = false
local function UpdateIntroState()
    vsIntroLine:ClearAllPoints()
    if vsExpanded then
        vsIntroExpanded:Show()
        vsIntroLine:SetPoint("TOPLEFT", vsIntroExpanded, "BOTTOMLEFT", 0, -10)
        -- Arrow pointing down (90° CW rotation of the right-pointing sprite)
        vsToggleArrow:SetTexCoord(0, 1, 0, 0, 1, 1, 1, 0)
        vsToggleLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
    else
        vsIntroExpanded:Hide()
        vsIntroLine:SetPoint("TOPLEFT", vsIntroSummary, "BOTTOMLEFT", 0, -10)
        -- Arrow pointing right (normal orientation)
        vsToggleArrow:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
        vsToggleLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    end
    vsIntroLine:SetPoint("TOPRIGHT", vsContent, "TOPRIGHT", -PAD, 0)
end

vsIntroToggleBtn:SetScript("OnClick", function()
    UI:ShowVoidShieldGuide()
end)
vsIntroToggleBtn:SetScript("OnEnter", function()
    vsToggleBg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.35)
end)
vsIntroToggleBtn:SetScript("OnLeave", function()
    vsToggleBg:SetColorTexture(C.accentSecondary[1], C.accentSecondary[2], C.accentSecondary[3], 0.15)
end)

UpdateIntroState()

-- ── Proc Chance ───────────────────────────────────────────────────────────

local chanceHdr = UI:MakeSectionHeader(vsContent, vsContent, 0, "Proc Chance")
chanceHdr:ClearAllPoints()
chanceHdr:SetPoint("TOPLEFT",  vsIntroLine, "BOTTOMLEFT", 0, -8)
chanceHdr:SetPoint("TOPRIGHT", vsContent,   "TOPRIGHT",   -PAD, 0)

local chanceCheck = UI:MakeCheckbox(vsContent, "Show proc chance", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showChance = val
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)
chanceCheck:SetPoint("TOPLEFT", chanceHdr, "BOTTOMLEFT", 0, -10)
chanceCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local chanceLabelCheck = UI:MakeCheckbox(vsContent, "Show \"Chance:\" label text", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showChanceLabel = val
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)
chanceLabelCheck:SetPoint("TOPLEFT", chanceCheck, "BOTTOMLEFT", 0, -4)
chanceLabelCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local chanceFontRow, chanceFontBox = makeFontRow(chanceLabelCheck, -8, "chanceFontSize", 18)
local chanceStrataRow, chanceStrataDd = makeStrataRow(chanceFontRow, -6, "chanceStrata")

-- ── Deck Count ────────────────────────────────────────────────────────────

local deckHdr = UI:MakeSectionHeader(vsContent, chanceStrataRow, -18, "Deck Count")

local deckCheck = UI:MakeCheckbox(vsContent, "Show deck count", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showDeck = val
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)
deckCheck:SetPoint("TOPLEFT", deckHdr, "BOTTOMLEFT", 0, -10)
deckCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local deckLabelCheck = UI:MakeCheckbox(vsContent, "Show \"Deck:\" label text", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showDeckLabel = val
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)
deckLabelCheck:SetPoint("TOPLEFT", deckCheck, "BOTTOMLEFT", 0, -4)
deckLabelCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local deckFontRow, deckFontBox = makeFontRow(deckLabelCheck, -8, "deckFontSize", 18)
local deckStrataRow, deckStrataDd = makeStrataRow(deckFontRow, -6, "deckStrata")

-- ── Deck of Cards ─────────────────────────────────────────────────────────

local cardsHdr = UI:MakeSectionHeader(vsContent, deckStrataRow, -18, "Deck of Cards")

local cardsCheck = UI:MakeCheckbox(vsContent, "Show deck cards", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.showCards = val
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)
cardsCheck:SetPoint("TOPLEFT", cardsHdr, "BOTTOMLEFT", 0, -10)
cardsCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local cardsRotateCheck = UI:MakeCheckbox(vsContent, "Stack cards vertically", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.cardsRotated = val
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end)
cardsRotateCheck:SetPoint("TOPLEFT", cardsCheck, "BOTTOMLEFT", 0, -4)
cardsRotateCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local cardsSizeSlider = UI:MakeSlider(vsContent, "Card size:", 8, 48, 1,
    function(val) return tostring(math.floor(val)) end,
    function(val)
        if PWT.db then PWT.db.voidShieldDeck.cardsSize = val end
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
    end)
cardsSizeSlider:SetPoint("TOPLEFT", cardsRotateCheck, "BOTTOMLEFT", 0, -8)
cardsSizeSlider:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local cardColorLabel = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
cardColorLabel:SetPoint("TOPLEFT", cardsSizeSlider, "BOTTOMLEFT", 0, -8)
cardColorLabel:SetText("Card color selector:")
cardColorLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procCardColor = makeCardColorPicker(cardColorLabel, 0, "Proc", "cardProcColor", {0.15, 0.75, 0.25})
local noProcCardColor = makeCardColorPicker(cardColorLabel, 76, "No Proc", "cardNoProcColor", {0.80, 0.15, 0.15})
local unknownCardColor = makeCardColorPicker(cardColorLabel, 152, "Unknown", "cardUnknownColor", {0.55, 0.52, 0.60})

local resetCardColorsBtn = UI:MakeButton(vsContent, "Reset Colors", function()
    if not (PWT.db and PWT.db.voidShieldDeck) then return end
    local cfg = PWT.db.voidShieldDeck
    cfg.cardProcColor = {0.15, 0.75, 0.25}
    cfg.cardNoProcColor = {0.80, 0.15, 0.15}
    cfg.cardUnknownColor = {0.55, 0.52, 0.60}
    procCardColor.set(0.15, 0.75, 0.25)
    noProcCardColor.set(0.80, 0.15, 0.15)
    unknownCardColor.set(0.55, 0.52, 0.60)
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:UpdateWidget() end
end, "default")
resetCardColorsBtn:SetSize(100, 24)
resetCardColorsBtn:SetPoint("TOPLEFT", procCardColor, "BOTTOMLEFT", 0, -6)

local cardsStrataRow, cardsStrataDd = makeStrataRow(resetCardColorsBtn, -8, "cardsStrata")

-- ── Position ──────────────────────────────────────────────────────────────

local posHdr = UI:MakeSectionHeader(vsContent, cardsStrataRow, -18, "Position")

local vsLockRow = UI:MakeLockResetRow(vsContent,
    function()  -- onLock
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:SetMovable(false) end
    end,
    function()  -- onUnlock
        if not (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled) then
            PWT:Print("Enable the Void Shield tracker first.")
            vsLockRow.setLocked(true)
            return
        end
        if PWT.VoidShieldDeck then
            PWT.VoidShieldDeck:ShowWidget()
            PWT.VoidShieldDeck:SetMovable(true)
        end
    end,
    function()  -- onReset
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:ResetPosition() end
        PWT:Print("Void Shield tracker position reset.")
    end,
    "Unlock to Move", "Lock Position")
vsLockRow:SetPoint("TOPLEFT", posHdr, "BOTTOMLEFT", 0, -10)
vsLockRow:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local posDesc = vsContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
posDesc:SetPoint("TOPLEFT", vsLockRow, "BOTTOMLEFT", 0, -4)
posDesc:SetWidth(CONTENT_W - PAD * 2)
posDesc:SetJustifyH("LEFT")
posDesc:SetText("Unlock the tracker to drag it anywhere on screen, then lock to save the position.")
posDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ── Proc Icon Alert ───────────────────────────────────────────────────────

local procIconHdr = UI:MakeSectionHeader(vsContent, posDesc, -18, "Proc Icon Alert")

local procAlertCheck = UI:MakeCheckbox(vsContent, "Show Void Shield icon when proc fires", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.procAlertEnabled = val
end)
procAlertCheck:SetPoint("TOPLEFT", procIconHdr, "BOTTOMLEFT", 0, -10)
procAlertCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local procAlertSizeSlider = UI:MakeSlider(vsContent, "Alert size:", 16, 256, 2,
    function(val) return tostring(math.floor(val)) end,
    function(val)
        if PWT.db then PWT.db.voidShieldDeck.procAlertSize = val end
        if PWT.VoidShieldDeck and PWT.VoidShieldDeck.procAlertWidget then
            PWT.VoidShieldDeck.procAlertWidget:SetSize(val, val)
        end
    end)
procAlertSizeSlider:SetPoint("TOPLEFT", procAlertCheck, "BOTTOMLEFT", 0, -8)
procAlertSizeSlider:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local procAlertStrataRow, procAlertStrataDd = makeStrataRow(procAlertSizeSlider, -8, "procAlertStrata")

local procAlertLockRow = UI:MakeLockResetRow(vsContent,
    function()  -- onLock
        if PWT.VoidShieldDeck then
            PWT.VoidShieldDeck:SetProcAlertMovable(false)
            PWT.VoidShieldDeck:HideProcAlertPreview()
        end
    end,
    function()  -- onUnlock
        if not (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled) then
            PWT:Print("Enable the Void Shield tracker first.")
            procAlertLockRow.setLocked(true)
            return
        end
        if PWT.VoidShieldDeck then
            PWT.VoidShieldDeck:SetProcAlertMovable(true)
            PWT.VoidShieldDeck:ShowProcAlertPreview()
        end
    end,
    function()  -- onReset
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:ResetProcAlertPosition() end
        PWT:Print("Proc alert position reset.")
    end,
    "Unlock to Move", "Lock Position")
procAlertLockRow:SetPoint("TOPLEFT", procAlertStrataRow, "BOTTOMLEFT", 0, -10)
procAlertLockRow:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

-- ── Proc Sound Alert ──────────────────────────────────────────────────────

local procSoundHdr = UI:MakeSectionHeader(vsContent, procAlertLockRow, -18, "Proc Sound Alert")

local procSoundCheck = UI:MakeCheckbox(vsContent, "Enable sound alert on proc", nil, function(val)
    if not PWT.db then return end
    PWT.db.voidShieldDeck.procSoundEnabled = val
end)
procSoundCheck:SetPoint("TOPLEFT", procSoundHdr, "BOTTOMLEFT", 0, -10)
procSoundCheck:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local procSoundPickRow = CreateFrame("Frame", nil, vsContent)
procSoundPickRow:SetHeight(24)
procSoundPickRow:SetPoint("TOPLEFT", procSoundCheck, "BOTTOMLEFT", 0, -8)
procSoundPickRow:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local procSoundLbl = procSoundPickRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
procSoundLbl:SetPoint("LEFT", procSoundPickRow, "LEFT", 0, 2)
procSoundLbl:SetText("Sound:")
procSoundLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procSoundDd = UI:MakeDropdown(procSoundPickRow,
    function()
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:BuildSoundList() end
        local list = (PWT.VoidShieldDeck and PWT.VoidShieldDeck.soundList) or {}
        local result = {}
        for i, entry in ipairs(list) do
            result[i] = { label = entry.label, value = i }
        end
        return result
    end,
    function(entry)
        if PWT.db and PWT.db.voidShieldDeck then
            PWT.db.voidShieldDeck.procSoundIndex = entry.value
        end
        local list = (PWT.VoidShieldDeck and PWT.VoidShieldDeck.soundList) or {}
        local name = (list[entry.value] and list[entry.value].label) or tostring(entry.value)
        if #name > 26 then name = name:sub(1, 23) .. "..." end
        procSoundDd.setLabel(name)
    end,
    {
        width       = 190,
        popupW      = 240,
        popupH      = 200,
        rowH        = 20,
        getSelected = function()
            return (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundIndex) or 5
        end,
    })
procSoundDd.button:SetPoint("LEFT", procSoundLbl, "RIGHT", 8, 0)

local procSoundPreviewBtn = UI:MakeButton(procSoundPickRow, "Preview", function()
    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:PlayProcSound() end
end, "default")
procSoundPreviewBtn:SetSize(60, 22)
procSoundPreviewBtn:SetPoint("LEFT", procSoundDd.button, "RIGHT", 6, 0)

local procVolSlider = UI:MakeSlider(vsContent, "Volume:", 0.0, 1.0, 0.05,
    function(val) return string.format("%d%%", math.floor(val * 100 + 0.5)) end,
    function(val)
        if PWT.db then PWT.db.voidShieldDeck.procSoundVolume = val end
    end)
procVolSlider:SetPoint("TOPLEFT", procSoundPickRow, "BOTTOMLEFT", 0, -8)
procVolSlider:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local VSD_CHANNELS = {
    { label = "SFX (Default)", value = "SFX"      },
    { label = "Master",        value = "Master"    },
    { label = "Music",         value = "Music"     },
    { label = "Ambience",      value = "Ambience"  },
    { label = "Dialog",        value = "Dialog"    },
}

local procChanRow = CreateFrame("Frame", nil, vsContent)
procChanRow:SetHeight(24)
procChanRow:SetPoint("TOPLEFT", procVolSlider, "BOTTOMLEFT", 0, -8)
procChanRow:SetPoint("RIGHT",   vsContent, "RIGHT", -PAD, 0)

local procChanLbl = procChanRow:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
procChanLbl:SetPoint("LEFT", procChanRow, "LEFT", 0, 2)
procChanLbl:SetText("Channel:")
procChanLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local procChanDd = UI:MakeDropdown(procChanRow, VSD_CHANNELS, function(entry)
    if PWT.db and PWT.db.voidShieldDeck then
        PWT.db.voidShieldDeck.procSoundChannel = entry.value
    end
    procChanDd.setLabel(entry.label)
end, {
    width       = 160,
    popupW      = 190,
    popupH      = #VSD_CHANNELS * 20 + 4,
    rowH        = 20,
    getSelected = function()
        return (PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.procSoundChannel) or "SFX"
    end,
})
procChanDd.button:SetPoint("LEFT", procChanLbl, "RIGHT", 8, 0)

-- ── Sync ──────────────────────────────────────────────────────────────────

function UI:SyncVoidShield()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck

    chanceCheck.set(cfg.showChance ~= false)
    chanceLabelCheck.set(cfg.showChanceLabel ~= false)
    deckCheck.set(cfg.showDeck ~= false)
    deckLabelCheck.set(cfg.showDeckLabel ~= false)
    cardsCheck.set(cfg.showCards ~= false)
    cardsRotateCheck.set(cfg.cardsRotated == true)

    chanceFontBox:SetText(tostring(cfg.chanceFontSize or 18))
    deckFontBox:SetText(tostring(cfg.deckFontSize or 18))
    cardsSizeSlider.set(cfg.cardsSize or 18)
    local procCol = cfg.cardProcColor or {0.15, 0.75, 0.25}
    local noProcCol = cfg.cardNoProcColor or {0.80, 0.15, 0.15}
    local unknownCol = cfg.cardUnknownColor or {0.55, 0.52, 0.60}
    procCardColor.set(procCol[1], procCol[2], procCol[3])
    noProcCardColor.set(noProcCol[1], noProcCol[2], noProcCol[3])
    unknownCardColor.set(unknownCol[1], unknownCol[2], unknownCol[3])

    chanceStrataDd.setLabel(cfg.chanceStrata    or "MEDIUM")
    deckStrataDd.setLabel(cfg.deckStrata         or "MEDIUM")
    cardsStrataDd.setLabel(cfg.cardsStrata       or "MEDIUM")

    vsLockRow.setLocked(true)

    procAlertCheck.set(cfg.procAlertEnabled == true)
    procAlertSizeSlider.set(cfg.procAlertSize or 64)
    procAlertStrataDd.setLabel(cfg.procAlertStrata or "HIGH")
    procAlertLockRow.setLocked(true)

    procSoundCheck.set(cfg.procSoundEnabled == true)

    if PWT.VoidShieldDeck then PWT.VoidShieldDeck:BuildSoundList() end
    local list    = (PWT.VoidShieldDeck and PWT.VoidShieldDeck.soundList) or {}
    local idx     = cfg.procSoundIndex or 5
    local sndName = (list[idx] and list[idx].label) or "Alarm Clock"
    if #sndName > 26 then sndName = sndName:sub(1, 23) .. "..." end
    procSoundDd.setLabel(sndName)

    procVolSlider.set(cfg.procSoundVolume or 1.0)

    local curChan = cfg.procSoundChannel or "SFX"
    for _, e in ipairs(VSD_CHANNELS) do
        if e.value == curChan then procChanDd.setLabel(e.label); break end
    end
end
