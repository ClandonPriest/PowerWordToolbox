-- ============================================================
--  Power Word: Toolbox  |  Options/UtilityReminders_Options.lua
--  Per-dungeon utility talent reminder configuration.
--  A table lets you check which spells to require per dungeon;
--  the module alerts you on dungeon entry if any are missing.
-- ============================================================

local _, PWT = ...
local UI  = PWT.UI
local UR  = PWT.UtilityReminders
local C   = UI.C
local PAD = UI.PAD

local urPanel = UI:AddTab("utility", "Reminders", 5)

-- ── Scroll wrapper ────────────────────────────────────────────
local urScroll = CreateFrame("ScrollFrame", nil, urPanel)
urScroll:SetAllPoints(urPanel)
urScroll:EnableMouseWheel(true)
urScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
end)

local urContent = CreateFrame("Frame", nil, urScroll)
urContent:SetWidth(UI.FRAME_W)
urContent:SetHeight(600)
urScroll:SetScrollChild(urContent)

-- ── Title ─────────────────────────────────────────────────────
local urTitle = urContent:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
urTitle:SetPoint("TOPLEFT", urContent, "TOPLEFT", PAD, -PAD)
urTitle:SetTextColor(C.text[1], C.text[2], C.text[3])
urTitle:SetText("Utility Reminders")

local urTitleLine = UI:MakeLine(urContent, C.border, 1)
urTitleLine:SetPoint("TOPLEFT",  urTitle, "BOTTOMLEFT",   0, -8)
urTitleLine:SetPoint("TOPRIGHT", urContent, "TOPRIGHT", -PAD, -8)

-- ── Description ───────────────────────────────────────────────
local urDesc = urContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
urDesc:SetPoint("TOPLEFT", urTitleLine, "BOTTOMLEFT", 0, -10)
urDesc:SetWidth(UI.FRAME_W - PAD * 2)
urDesc:SetJustifyH("LEFT")
urDesc:SetText("Check a spell for a dungeon to be alerted on entry if you do not have that talent.")
urDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local urDescLine = UI:MakeLine(urContent, C.border, 1)
urDescLine:SetPoint("TOPLEFT",  urDesc, "BOTTOMLEFT",   0, -10)
urDescLine:SetPoint("TOPRIGHT", urContent, "TOPRIGHT", -PAD, -10)

-- ── Table constants ───────────────────────────────────────────
-- Row/header frames are anchored TOPLEFT→prevElement and TOPRIGHT→urContent,
-- giving each frame a width of (UI.FRAME_W - PAD*2) = 428px.
-- Column layout within those 428px:
--   x  0 .. 188  →  dungeon name  (DUNG_W)
--   x 188 .. 268  →  Shackle Horror column  (SPELL_W)
--   x 268 .. 348  →  Improved Purify column
--   x 348 .. 428  →  Phantasm column

local DUNG_W  = 188
local SPELL_W = 80
local HDR_H   = 42
local ROW_H   = 26

-- Vertical divider helper — adds a 1-px line at the given x offset
local function AddDividers(parent, height)
    for ci = 0, 2 do
        local x = DUNG_W + ci * SPELL_W
        local div = parent:CreateTexture(nil, "ARTWORK")
        div:SetWidth(1)
        div:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.55)
        div:SetPoint("TOPLEFT",    parent, "TOPLEFT",    x, 0)
        div:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 0)
    end
end

-- ── Header row ────────────────────────────────────────────────
local hdrFrame = CreateFrame("Frame", nil, urContent)
hdrFrame:SetHeight(HDR_H)
hdrFrame:SetPoint("TOPLEFT",  urDescLine, "BOTTOMLEFT",  0, -10)
hdrFrame:SetPoint("TOPRIGHT", urContent,  "TOPRIGHT",   -PAD, -10)

-- Header background (slightly lighter than content rows)
local hdrBg = hdrFrame:CreateTexture(nil, "BACKGROUND")
hdrBg:SetAllPoints(hdrFrame)
hdrBg:SetColorTexture(0.14, 0.13, 0.18, 0.90)

-- "Dungeon" label
local hdrDungLbl = hdrFrame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
hdrDungLbl:SetPoint("LEFT", hdrFrame, "LEFT", 6, 0)
hdrDungLbl:SetWidth(DUNG_W - 10)
hdrDungLbl:SetJustifyH("LEFT")
hdrDungLbl:SetText("Dungeon")
hdrDungLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Spell column header labels (centered in each column)
for i, spell in ipairs(UR.SPELLS) do
    local colLeft = DUNG_W + (i - 1) * SPELL_W
    local lbl = hdrFrame:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    lbl:SetWidth(SPELL_W - 4)
    lbl:SetPoint("TOP", hdrFrame, "TOPLEFT", colLeft + SPELL_W / 2, -6)
    lbl:SetJustifyH("CENTER")
    lbl:SetText(spell.headerLabel)
    lbl:SetTextColor(C.text[1], C.text[2], C.text[3])
end

AddDividers(hdrFrame, HDR_H)

-- Header bottom separator
local hdrLine = UI:MakeLine(urContent, C.border, 1)
hdrLine:SetPoint("TOPLEFT",  hdrFrame, "BOTTOMLEFT",  0, 0)
hdrLine:SetPoint("TOPRIGHT", hdrFrame, "BOTTOMRIGHT", 0, 0)

-- ── Data rows ─────────────────────────────────────────────────
-- urCheckboxes[dungeonKey][spellKey] → CheckButton  (used by SyncUtilityReminders)
local urCheckboxes = {}

local prevAnchor = hdrLine

for ri, dungeon in ipairs(UR.DUNGEONS) do
    local isEven = (ri % 2 == 0)
    local bgColor = isEven and C.rowEven or C.rowOdd

    local row = CreateFrame("Frame", nil, urContent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT",  prevAnchor, "BOTTOMLEFT",  0, 0)
    row:SetPoint("TOPRIGHT", urContent,  "TOPRIGHT",   -PAD, 0)

    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints(row)
    rowBg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    -- Dungeon name
    local nameLbl = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    nameLbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
    nameLbl:SetWidth(DUNG_W - 10)
    nameLbl:SetJustifyH("LEFT")
    nameLbl:SetText(dungeon.name)
    nameLbl:SetTextColor(C.text[1], C.text[2], C.text[3])

    -- Spell checkboxes (one per column, centered)
    urCheckboxes[dungeon.key] = {}
    for ci, spell in ipairs(UR.SPELLS) do
        local colCenterX = DUNG_W + (ci - 1) * SPELL_W + SPELL_W / 2
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("LEFT", row, "LEFT", colCenterX - 12, 0)
        -- hide the built-in text label that comes with the template
        if cb.text then cb.text:SetText("") end

        cb:SetScript("OnClick", function(self)
            local db = PWT.db
            if db and db.utilityReminders and db.utilityReminders.checks[dungeon.key] then
                db.utilityReminders.checks[dungeon.key][spell.key] = self:GetChecked() and true or false
            end
        end)

        urCheckboxes[dungeon.key][spell.key] = cb
    end

    AddDividers(row, ROW_H)
    prevAnchor = row
end

-- ── Reset button ───────────────────────────────────────────────
local resetBtn = CreateFrame("Button", nil, urContent, "UIPanelButtonTemplate")
resetBtn:SetSize(130, 26)
resetBtn:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -10)
resetBtn:SetText("Reset to Default")
resetBtn:SetScript("OnClick", function()
    if not PWT.db or not PWT.db.utilityReminders then return end
    local checks = PWT.db.utilityReminders.checks
    local defChecks = PWT.defaults.utilityReminders.checks
    for dkey, defDung in pairs(defChecks) do
        if not checks[dkey] then checks[dkey] = {} end
        for skey, defVal in pairs(defDung) do
            checks[dkey][skey] = defVal
        end
    end
    UI:SyncUtilityReminders()
end)

-- ── Alert Anchor ──────────────────────────────────────────────

local anchorLine = UI:MakeLine(urContent, C.border, 1)
anchorLine:SetPoint("TOPLEFT",  resetBtn, "BOTTOMLEFT",  0, -12)
anchorLine:SetPoint("TOPRIGHT", urContent,  "TOPRIGHT",   -PAD, -12)

local anchorHeader = urContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
anchorHeader:SetPoint("TOPLEFT", anchorLine, "BOTTOMLEFT", 0, -12)
anchorHeader:SetText("Alert Anchor")
anchorHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

local anchorDesc = urContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
anchorDesc:SetPoint("TOPLEFT", anchorHeader, "BOTTOMLEFT", 0, -4)
anchorDesc:SetWidth(UI.FRAME_W - PAD * 2)
anchorDesc:SetJustifyH("LEFT")
anchorDesc:SetText("Click Move to reposition the alert on screen.")
anchorDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Move / Done toggle button
local isMoving = false

local moveBtn = CreateFrame("Button", nil, urContent, "UIPanelButtonTemplate")
moveBtn:SetSize(110, 26)
moveBtn:SetPoint("TOPLEFT", anchorDesc, "BOTTOMLEFT", 0, -10)
moveBtn:SetText("Move Alert")
moveBtn:SetScript("OnClick", function(self)
    isMoving = not isMoving
    if PWT.UtilityReminders then
        PWT.UtilityReminders:SetAlertMovable(isMoving)
    end
    self:SetText(isMoving and "Done" or "Move Alert")
end)

-- Size slider  (10 – 100)
local sizeLabel = urContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
sizeLabel:SetPoint("TOPLEFT", moveBtn, "BOTTOMLEFT", 0, -16)
sizeLabel:SetText("Alert Size:")
sizeLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local sizeSlider = CreateFrame("Slider", nil, urContent)
sizeSlider:SetOrientation("HORIZONTAL")
sizeSlider:SetSize(160, 16)
sizeSlider:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
sizeSlider:SetMinMaxValues(10, 100)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)

local sliderTrack = sizeSlider:CreateTexture(nil, "BACKGROUND")
sliderTrack:SetPoint("LEFT",  sizeSlider, "LEFT",  4, 0)
sliderTrack:SetPoint("RIGHT", sizeSlider, "RIGHT", -4, 0)
sliderTrack:SetHeight(4)
sliderTrack:SetColorTexture(0.25, 0.25, 0.25, 1)

sizeSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
sizeSlider:GetThumbTexture():SetSize(16, 16)

local sizeValue = urContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
sizeValue:SetPoint("LEFT", sizeSlider, "RIGHT", 8, 0)
sizeValue:SetTextColor(C.text[1], C.text[2], C.text[3])

sizeSlider:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v + 0.5)
    sizeValue:SetText(tostring(v))
    if PWT.db and PWT.db.utilityReminders then
        PWT.db.utilityReminders.alertSize = v
    end
    if PWT.UtilityReminders then
        PWT.UtilityReminders:ApplyAlertSize(v)
    end
end)

-- ── Sync ──────────────────────────────────────────────────────
function UI:SyncUtilityReminders()
    if not PWT.db or not PWT.db.utilityReminders then return end

    -- If move mode was left open from a previous visit, close it cleanly
    if isMoving then
        isMoving = false
        moveBtn:SetText("Move Alert")
        if PWT.UtilityReminders then PWT.UtilityReminders:SetAlertMovable(false) end
    end

    local db = PWT.db.utilityReminders
    sizeSlider:SetValue(db.alertSize or 18)

    local checks = db.checks
    for _, dungeon in ipairs(UR.DUNGEONS) do
        local dc = checks[dungeon.key]
        if dc then
            for _, spell in ipairs(UR.SPELLS) do
                local cb = urCheckboxes[dungeon.key] and urCheckboxes[dungeon.key][spell.key]
                if cb then
                    local v = dc[spell.key]
                    cb:SetChecked(v ~= nil and v ~= false)
                end
            end
        end
    end
end
