-- ============================================================
--  Power Word: Toolbox  |  Options/General.lua
--  General settings tab: modules, chat messages, login message,
--  debug mode, per-module debug filters, and interface font.
-- ============================================================

local _, PWT = ...
local UI  = PWT.UI
local C   = UI.C
local PAD = UI.PAD

local generalPanel = UI:AddTab("general", "General", 1)

-- ── Scroll container ──────────────────────────────────────────
-- Wraps all content so the debug-module checkboxes don't push
-- the font picker out of view.  Mouse-wheel scrolls when needed.
local genScroll = CreateFrame("ScrollFrame", nil, generalPanel)
genScroll:SetAllPoints(generalPanel)
genScroll:EnableMouseWheel(true)
genScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
end)

local genContent = CreateFrame("Frame", nil, genScroll)
genContent:SetWidth(UI.FRAME_W)
genContent:SetHeight(480)   -- updated by UpdateContentHeight()
genScroll:SetScrollChild(genContent)

-- ── Title ────────────────────────────────────────────────────

local genTitle = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
genTitle:SetPoint("TOPLEFT", genContent, "TOPLEFT", PAD, -PAD)
genTitle:SetTextColor(C.text[1], C.text[2], C.text[3])
genTitle:SetText("General Settings")

local genLine = UI:MakeLine(genContent, C.border, 1)
genLine:SetPoint("TOPLEFT",  genTitle, "BOTTOMLEFT",   0, -8)
genLine:SetPoint("TOPRIGHT", genContent, "TOPRIGHT", -PAD, -8)

-- ── Modules ──────────────────────────────────────────────────

local modulesHeader = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
modulesHeader:SetPoint("TOPLEFT", genLine, "BOTTOMLEFT", 0, -12)
modulesHeader:SetText("Modules")
modulesHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

local modulesDesc = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
modulesDesc:SetPoint("TOPLEFT", modulesHeader, "BOTTOMLEFT", 0, -4)
modulesDesc:SetWidth(UI.FRAME_W - PAD * 2)
modulesDesc:SetJustifyH("LEFT")
modulesDesc:SetText("Enable or disable each module. Disabled modules show a red indicator on their tab.")
modulesDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local modPICheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
modPICheck:SetPoint("TOPLEFT", modulesDesc, "BOTTOMLEFT", -2, -6)
modPICheck.text:SetText("Power Infusion")
modPICheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
modPICheck:SetScript("OnClick", function(self)
    PWT.db.piEnabled = self:GetChecked()
    UI:SetTabEnabled("pi", self:GetChecked())
end)

local modAtCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
modAtCheck:SetPoint("TOPLEFT", modPICheck, "BOTTOMLEFT", 0, -2)
modAtCheck.text:SetText("Atonement Tracker")
modAtCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
modAtCheck:SetScript("OnClick", function(self)
    PWT.db.atonement.enabled = self:GetChecked()
    if self:GetChecked() then
        if PWT.Atonement then PWT.Atonement:UpdateWidget() end
    else
        if PWT.Atonement then PWT.Atonement:HideWidget() end
    end
    UI:SetTabEnabled("atonement", self:GetChecked())
end)

local modRadCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
modRadCheck:SetPoint("TOPLEFT", modAtCheck, "BOTTOMLEFT", 0, -2)
modRadCheck.text:SetText("Radiance Bars")
modRadCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
modRadCheck:SetScript("OnClick", function(self)
    local enabled = self:GetChecked()
    if not PWT.db.radiance then PWT.db.radiance = {} end
    PWT.db.radiance.enabled = enabled
    if enabled then
        if PWT.isDisc and PWT.Radiance then PWT.Radiance:ShowWidget() end
    else
        if PWT.Radiance then PWT.Radiance:HideWidget() end
    end
    UI:SetTabEnabled("radiance", enabled)
end)

local modVSCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
modVSCheck:SetPoint("TOPLEFT", modRadCheck, "BOTTOMLEFT", 0, -2)
modVSCheck.text:SetText("Void Shield Deck Tracker")
modVSCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
modVSCheck:SetScript("OnClick", function(self)
    local enabled = self:GetChecked()
    if not PWT.db.voidShieldDeck then PWT.db.voidShieldDeck = {} end
    PWT.db.voidShieldDeck.enabled = enabled
    if enabled then
        if PWT.isDisc and PWT.VoidShieldDeck then PWT.VoidShieldDeck:ShowWidget() end
    else
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:HideWidget() end
    end
    UI:SetTabEnabled("voidshield", enabled)
end)

local modURCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
modURCheck:SetPoint("TOPLEFT", modVSCheck, "BOTTOMLEFT", 0, -2)
modURCheck.text:SetText("Utility Reminders")
modURCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
modURCheck:SetScript("OnClick", function(self)
    if PWT.db.utilityReminders then
        PWT.db.utilityReminders.enabled = self:GetChecked()
    end
    UI:SetTabEnabled("utility", self:GetChecked())
end)

local genLine4 = UI:MakeLine(genContent, C.border, 1)
genLine4:SetPoint("TOPLEFT",  modURCheck, "BOTTOMLEFT",   0, -10)
genLine4:SetPoint("TOPRIGHT", genContent,  "TOPRIGHT", -PAD, -10)

-- ── General Settings ──────────────────────────────────────────

-- Chat messages
local chatCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
chatCheck:SetPoint("TOPLEFT", genLine4, "BOTTOMLEFT", 0, -10)
chatCheck.text:SetText("Show chat notifications")
chatCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
chatCheck:SetScript("OnClick", function(self) PWT.db.showChatMessages = self:GetChecked() end)

local chatDesc = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
chatDesc:SetPoint("TOPLEFT", chatCheck, "BOTTOMLEFT", 26, -2)
chatDesc:SetWidth(UI.FRAME_W - PAD * 2 - 30)
chatDesc:SetJustifyH("LEFT")
chatDesc:SetText("Prints addon messages to chat (e.g. PI target alerts). Disable to run silently.")
chatDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Login message
local loginCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
loginCheck:SetPoint("TOPLEFT", chatDesc, "BOTTOMLEFT", -26, -8)
loginCheck.text:SetText("Show login message")
loginCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])
loginCheck:SetScript("OnClick", function(self) PWT.db.showLoginMessage = self:GetChecked() end)

local loginDesc = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
loginDesc:SetPoint("TOPLEFT", loginCheck, "BOTTOMLEFT", 26, -2)
loginDesc:SetWidth(UI.FRAME_W - PAD * 2 - 30)
loginDesc:SetJustifyH("LEFT")
loginDesc:SetText("Shows the 'Loaded! Type /pwtb' message on login.")
loginDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- Debug mode
local debugCheck = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
debugCheck:SetPoint("TOPLEFT", loginDesc, "BOTTOMLEFT", -26, -8)
debugCheck.text:SetText("Enable debug mode")
debugCheck.text:SetTextColor(C.text[1], C.text[2], C.text[3])

local genDesc = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
genDesc:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 26, -2)
genDesc:SetWidth(UI.FRAME_W - PAD * 2 - 30)
genDesc:SetJustifyH("LEFT")
genDesc:SetText("Prints verbose output to chat for troubleshooting. Disable during normal use.")
genDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ── Per-module debug filters (only visible when debug is ON) ─

local debugModulesLabel = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
debugModulesLabel:SetPoint("TOPLEFT", genDesc, "BOTTOMLEFT", 0, -10)
debugModulesLabel:SetText("Active modules:")
debugModulesLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local MODULE_CHECKS = {
    { key = "pi",         label = "Power Infusion"    },
    { key = "atonement",  label = "Atonement"         },
    { key = "radiance",   label = "Radiance"          },
    { key = "voidshield", label = "Void Shield"       },
    { key = "utility",    label = "Utility Reminders" },
    { key = "ui",         label = "UI / Core"         },
}

local moduleCheckFrames = {}
local prevAnchor = debugModulesLabel

for i, mod in ipairs(MODULE_CHECKS) do
    local cb = CreateFrame("CheckButton", nil, genContent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, i == 1 and -4 or -2)
    cb.text:SetText(mod.label)
    cb.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    cb:SetScript("OnClick", function(self)
        if PWT.db and PWT.db.debugModules then
            PWT.db.debugModules[mod.key] = self:GetChecked()
        end
    end)
    cb.modKey = mod.key
    moduleCheckFrames[i] = cb
    prevAnchor = cb
end

-- Separator between General Settings and Audio Channel sections.
-- Re-anchored dynamically when debug filters are shown/hidden.
local genLine2 = UI:MakeLine(genContent, C.border, 1)
genLine2:SetPoint("TOPLEFT",  genDesc, "BOTTOMLEFT", 0, -12)
genLine2:SetPoint("TOPRIGHT", genContent, "TOPRIGHT", -PAD, -12)

-- ── Audio Channel ─────────────────────────────────────────────

local SOUND_CHANNELS = {
    { label = "SFX (Default)",  value = "SFX"      },
    { label = "Master",         value = "Master"    },
    { label = "Music",          value = "Music"     },
    { label = "Ambience",       value = "Ambience"  },
    { label = "Dialog",         value = "Dialog"    },
}

local chanHeader = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
chanHeader:SetPoint("TOPLEFT", genLine2, "BOTTOMLEFT", 0, -12)
chanHeader:SetText("Audio Channel")
chanHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

local chanHeaderDesc = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
chanHeaderDesc:SetPoint("TOPLEFT", chanHeader, "BOTTOMLEFT", 0, -4)
chanHeaderDesc:SetWidth(UI.FRAME_W - PAD * 2)
chanHeaderDesc:SetJustifyH("LEFT")
chanHeaderDesc:SetText("The in-game sound channel all addon audio alerts are played through.")
chanHeaderDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

local chanDropBtn = CreateFrame("Button", nil, genContent, "UIPanelButtonTemplate")
chanDropBtn:SetSize(210, 24)
chanDropBtn:SetPoint("TOPLEFT", chanHeaderDesc, "BOTTOMLEFT", 0, -8)
chanDropBtn:GetFontString():SetText("SFX (Default)")

-- Separator between Audio Channel and Font sections.
local genLine3 = UI:MakeLine(genContent, C.border, 1)
genLine3:SetPoint("TOPLEFT",  chanDropBtn, "BOTTOMLEFT",   0, -12)
genLine3:SetPoint("TOPRIGHT", genContent,  "TOPRIGHT", -PAD, -12)

-- ── Custom scrollable channel dropdown ───────────────────────

local CHAN_DROP_H    = #SOUND_CHANNELS * 20 + 8
local CHAN_ROW_H     = 20
local CHAN_DROP_W    = 248
local CHAN_ROW_INN_W = CHAN_DROP_W - 30

local chanPopup = CreateFrame("Frame", "PWT_ChanDropPanel", UIParent)
chanPopup:SetSize(CHAN_DROP_W, CHAN_DROP_H)
chanPopup:SetFrameStrata("TOOLTIP")
chanPopup:SetFrameLevel(100)
chanPopup:Hide()
UI:MakeBg(chanPopup, {0.06, 0.06, 0.08, 0.98})

local function addChanBorderLine(p1, rp)
    local t = chanPopup:CreateTexture(nil, "OVERLAY")
    t:SetHeight(1)
    t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
    t:SetPoint(p1, chanPopup, rp, 0, 0)
    t:SetPoint(p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT",
               chanPopup, p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
end
addChanBorderLine("TOPLEFT",    "TOPLEFT")
addChanBorderLine("BOTTOMLEFT", "BOTTOMLEFT")

local chanScroll = CreateFrame("ScrollFrame", nil, chanPopup, "UIPanelScrollFrameTemplate")
chanScroll:SetPoint("TOPLEFT",     chanPopup, "TOPLEFT",     4, -4)
chanScroll:SetPoint("BOTTOMRIGHT", chanPopup, "BOTTOMRIGHT", -22, 4)

local chanScrollChild = CreateFrame("Frame", nil, chanScroll)
chanScrollChild:SetWidth(CHAN_ROW_INN_W)
chanScrollChild:SetHeight(#SOUND_CHANNELS * CHAN_ROW_H)
chanScroll:SetScrollChild(chanScrollChild)

local chanPopupRows = {}

local function GetChannelLabel(value)
    for _, e in ipairs(SOUND_CHANNELS) do
        if e.value == value then return e.label end
    end
    return "SFX (Default)"
end

local function HideChanDropdown()
    chanPopup:Hide()
end

local function PopulateChanDropdown()
    for _, r in ipairs(chanPopupRows) do r:Hide() end
    wipe(chanPopupRows)

    local currentVal = (PWT.db and PWT.db.pi and PWT.db.pi.soundChannel) or "SFX"

    for i, entry in ipairs(SOUND_CHANNELS) do
        local row = CreateFrame("Button", nil, chanScrollChild)
        row:SetSize(CHAN_ROW_INN_W, CHAN_ROW_H)
        row:SetPoint("TOPLEFT", chanScrollChild, "TOPLEFT", 0, -(i - 1) * CHAN_ROW_H)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        row.bg = rowBg

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
        rowLabel:SetPoint("LEFT",  row, "LEFT",  6, 0)
        rowLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rowLabel:SetJustifyH("LEFT")
        rowLabel:SetText(entry.label)

        local isSelected = (entry.value == currentVal)
        rowBg:SetColorTexture(
            isSelected and C.tabActive[1] or 0,
            isSelected and C.tabActive[2] or 0,
            isSelected and C.tabActive[3] or 0,
            isSelected and C.tabActive[4] or 0)
        rowLabel:SetTextColor(
            isSelected and C.textAccent[1] or C.text[1],
            isSelected and C.textAccent[2] or C.text[2],
            isSelected and C.textAccent[3] or C.text[3])

        row:SetScript("OnEnter", function(self)
            local cur = (PWT.db and PWT.db.pi and PWT.db.pi.soundChannel) or "SFX"
            if entry.value ~= cur then
                self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6)
            end
        end)
        row:SetScript("OnLeave", function(self)
            local cur = (PWT.db and PWT.db.pi and PWT.db.pi.soundChannel) or "SFX"
            local active = (entry.value == cur)
            self.bg:SetColorTexture(
                active and C.tabActive[1] or 0,
                active and C.tabActive[2] or 0,
                active and C.tabActive[3] or 0,
                active and C.tabActive[4] or 0)
        end)
        row:SetScript("OnClick", function()
            if PWT.db and PWT.db.pi then
                PWT.db.pi.soundChannel = entry.value
            end
            chanDropBtn:GetFontString():SetText(entry.label)
            HideChanDropdown()
        end)

        row:Show()
        chanPopupRows[i] = row
    end
end

-- Full-screen watcher to close dropdown on click-outside
local chanDropWatcher = CreateFrame("Frame", nil, UIParent)
chanDropWatcher:SetAllPoints(UIParent)
chanDropWatcher:SetFrameStrata("DIALOG")
chanDropWatcher:EnableMouse(false)
chanDropWatcher:Hide()
chanPopup:HookScript("OnShow", function()
    chanDropWatcher:EnableMouse(true)
    chanDropWatcher:Show()
    chanDropWatcher:SetScript("OnMouseDown", function(self)
        HideChanDropdown()
        self:EnableMouse(false)
        self:Hide()
    end)
end)

chanDropBtn:SetScript("OnClick", function(self)
    if chanPopup:IsShown() then
        HideChanDropdown()
        chanDropWatcher:EnableMouse(false)
        chanDropWatcher:Hide()
    else
        PopulateChanDropdown()
        chanPopup:ClearAllPoints()
        chanPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        chanPopup:Show()
    end
end)

local function UpdateContentHeight(on)
    -- Without debug filters: ~620px of content; with them: ~740px.
    genContent:SetHeight(on and 740 or 620)
    if not on then
        genScroll:SetVerticalScroll(0)
    end
end

local function UpdateDebugModuleVisibility()
    local on = PWT.db and PWT.db.debug
    debugModulesLabel:SetShown(on)
    for _, cb in ipairs(moduleCheckFrames) do cb:SetShown(on) end

    -- Move the separator so Font section follows whatever is currently visible
    genLine2:ClearAllPoints()
    if on then
        genLine2:SetPoint("TOPLEFT",  moduleCheckFrames[#moduleCheckFrames], "BOTTOMLEFT", 0, -12)
        genLine2:SetPoint("TOPRIGHT", genContent, "TOPRIGHT", -PAD, -12)
    else
        genLine2:SetPoint("TOPLEFT",  genDesc, "BOTTOMLEFT", 0, -12)
        genLine2:SetPoint("TOPRIGHT", genContent, "TOPRIGHT", -PAD, -12)
    end

    UpdateContentHeight(on)
end

debugCheck:SetScript("OnClick", function(self)
    PWT.db.debug = self:GetChecked()
    PWT:Print("Debug mode: " .. (PWT.db.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    UpdateDebugModuleVisibility()
end)

-- ── Interface Font ────────────────────────────────────────────

local fontHeader = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontNormal")
fontHeader:SetPoint("TOPLEFT", genLine3, "BOTTOMLEFT", 0, -12)
fontHeader:SetText("Interface Font")
fontHeader:SetTextColor(C.text[1], C.text[2], C.text[3])

-- Built-in WoW fonts always present as a baseline
local BUILTIN_FONTS = {
    { label = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF" },
    { label = "Arial Narrow",            path = "Fonts\\ARIALN.TTF"   },
    { label = "Morpheus",                path = "Fonts\\MORPHEUS.TTF" },
    { label = "Skurri",                  path = "Fonts\\SKURRI.TTF"   },
}

-- fontList is built lazily each time the dropdown opens so that LSM fonts
-- registered by other addons (ElvUI, SharedMediaAdditionalFonts, etc.) are
-- always picked up regardless of addon load order.
local fontList = {}

local function BuildFontList()
    wipe(fontList)
    for _, f in ipairs(BUILTIN_FONTS) do
        fontList[#fontList + 1] = { label = f.label, path = f.path }
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = LSM:List("font")
        if names then
            table.sort(names)
            local seen = {}
            for _, f in ipairs(fontList) do seen[f.path] = true end
            for _, name in ipairs(names) do
                local path = LSM:Fetch("font", name)
                if path and not seen[path] then
                    fontList[#fontList + 1] = { label = name, path = path }
                    seen[path] = true
                end
            end
        end
    end
end

local function GetFontLabel(path)
    for _, e in ipairs(fontList) do
        if e.path == path then return e.label end
    end
    for _, e in ipairs(BUILTIN_FONTS) do
        if e.path == path then return e.label end
    end
    return "Friz Quadrata (Default)"
end

local fontDropBtn = CreateFrame("Button", nil, genContent, "UIPanelButtonTemplate")
fontDropBtn:SetSize(210, 24)
fontDropBtn:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", 0, -8)
fontDropBtn:GetFontString():SetText("Friz Quadrata (Default)")

local fontDropDesc = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
fontDropDesc:SetPoint("TOPLEFT", fontDropBtn, "BOTTOMLEFT", 0, -4)
fontDropDesc:SetWidth(UI.FRAME_W - PAD * 2)
fontDropDesc:SetJustifyH("LEFT")
fontDropDesc:SetText("Changes the font across the options panel and widgets. Supports LibSharedMedia-3.0.")
fontDropDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ── Custom scrollable font dropdown ──────────────────────────

local FONT_DROP_H    = 200
local FONT_ROW_H     = 20
local FONT_DROP_W    = 248
local FONT_ROW_INN_W = FONT_DROP_W - 30  -- minus scroll bar

local fontPopup = CreateFrame("Frame", "PWT_FontDropPanel", UIParent)
fontPopup:SetSize(FONT_DROP_W, FONT_DROP_H)
fontPopup:SetFrameStrata("TOOLTIP")
fontPopup:SetFrameLevel(100)
fontPopup:Hide()
UI:MakeBg(fontPopup, {0.06, 0.06, 0.08, 0.98})

local function addFontBorderLine(p1, rp)
    local t = fontPopup:CreateTexture(nil, "OVERLAY")
    t:SetHeight(1)
    t:SetColorTexture(C.border[1], C.border[2], C.border[3], C.border[4])
    t:SetPoint(p1, fontPopup, rp, 0, 0)
    t:SetPoint(p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT",
               fontPopup, p1 == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
end
addFontBorderLine("TOPLEFT",    "TOPLEFT")
addFontBorderLine("BOTTOMLEFT", "BOTTOMLEFT")

local fontScroll = CreateFrame("ScrollFrame", nil, fontPopup, "UIPanelScrollFrameTemplate")
fontScroll:SetPoint("TOPLEFT",     fontPopup, "TOPLEFT",     4, -4)
fontScroll:SetPoint("BOTTOMRIGHT", fontPopup, "BOTTOMRIGHT", -22, 4)

local fontScrollChild = CreateFrame("Frame", nil, fontScroll)
fontScrollChild:SetWidth(FONT_ROW_INN_W)
fontScrollChild:SetHeight(1)
fontScroll:SetScrollChild(fontScrollChild)

local fontPopupRows = {}

local function HideFontDropdown()
    fontPopup:Hide()
end

local function PopulateFontDropdown()
    for _, r in ipairs(fontPopupRows) do r:Hide() end
    wipe(fontPopupRows)

    local currentPath = PWT.db and PWT.db.font or "Fonts\\FRIZQT__.TTF"

    for i, entry in ipairs(fontList) do
        local row = CreateFrame("Button", nil, fontScrollChild)
        row:SetSize(FONT_ROW_INN_W, FONT_ROW_H)
        row:SetPoint("TOPLEFT", fontScrollChild, "TOPLEFT", 0, -(i - 1) * FONT_ROW_H)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        row.bg = rowBg

        local rowLabel = row:CreateFontString(nil, "OVERLAY")
        rowLabel:SetPoint("LEFT",  row, "LEFT",  6, 0)
        rowLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        rowLabel:SetJustifyH("LEFT")
        -- Preview the font by rendering the name in its own typeface.
        -- pcall guards against any invalid path from an LSM entry.
        if not pcall(function() rowLabel:SetFont(entry.path, 12, "") end) then
            rowLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        end
        rowLabel:SetText(entry.label)

        local isSelected = (entry.path == currentPath)
        rowBg:SetColorTexture(
            isSelected and C.tabActive[1] or 0,
            isSelected and C.tabActive[2] or 0,
            isSelected and C.tabActive[3] or 0,
            isSelected and C.tabActive[4] or 0)
        rowLabel:SetTextColor(
            isSelected and C.textAccent[1] or C.text[1],
            isSelected and C.textAccent[2] or C.text[2],
            isSelected and C.textAccent[3] or C.text[3])

        row:SetScript("OnEnter", function(self)
            if entry.path ~= (PWT.db and PWT.db.font) then
                self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6)
            end
        end)
        row:SetScript("OnLeave", function(self)
            local active = entry.path == (PWT.db and PWT.db.font)
            self.bg:SetColorTexture(
                active and C.tabActive[1] or 0,
                active and C.tabActive[2] or 0,
                active and C.tabActive[3] or 0,
                active and C.tabActive[4] or 0)
        end)
        row:SetScript("OnClick", function()
            PWT.db.font = entry.path
            fontDropBtn:GetFontString():SetText(entry.label)
            HideFontDropdown()
            UI:ApplyFont(entry.path)
        end)

        row:Show()
        fontPopupRows[i] = row
    end

    local totalH = #fontList * FONT_ROW_H
    fontScrollChild:SetHeight(math.max(totalH, 1))

    -- Scroll to reveal the currently selected entry
    local selIdx = 1
    for i, e in ipairs(fontList) do
        if e.path == currentPath then selIdx = i; break end
    end
    local scrollMax = math.max(0, totalH - FONT_DROP_H + 8)
    local scrollTo  = math.max(0, math.min(scrollMax,
        (selIdx - 1) * FONT_ROW_H - FONT_DROP_H / 2))
    fontScroll:SetVerticalScroll(scrollTo)
end

-- Full-screen watcher to close dropdown on click-outside
local fontDropWatcher = CreateFrame("Frame", nil, UIParent)
fontDropWatcher:SetAllPoints(UIParent)
fontDropWatcher:SetFrameStrata("DIALOG")
fontDropWatcher:EnableMouse(false)
fontDropWatcher:Hide()
fontPopup:HookScript("OnShow", function()
    fontDropWatcher:EnableMouse(true)
    fontDropWatcher:Show()
    fontDropWatcher:SetScript("OnMouseDown", function(self)
        HideFontDropdown()
        self:EnableMouse(false)
        self:Hide()
    end)
end)

fontDropBtn:SetScript("OnClick", function(self)
    if fontPopup:IsShown() then
        HideFontDropdown()
        fontDropWatcher:EnableMouse(false)
        fontDropWatcher:Hide()
    else
        BuildFontList()
        PopulateFontDropdown()
        fontPopup:ClearAllPoints()
        fontPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        fontPopup:Show()
    end
end)

-- ── Sync ─────────────────────────────────────────────────────

function UI:SyncGeneral()
    if not PWT.db then return end
    chatCheck:SetChecked(PWT.db.showChatMessages)
    loginCheck:SetChecked(PWT.db.showLoginMessage)
    debugCheck:SetChecked(PWT.db.debug)
    local mods = PWT.db.debugModules or {}
    for _, cb in ipairs(moduleCheckFrames) do
        cb:SetChecked(mods[cb.modKey] ~= false)
    end
    UpdateDebugModuleVisibility()
    local chanVal = (PWT.db.pi and PWT.db.pi.soundChannel) or "SFX"
    chanDropBtn:GetFontString():SetText(GetChannelLabel(chanVal))
    BuildFontList()
    fontDropBtn:GetFontString():SetText(GetFontLabel(PWT.db.font or "Fonts\\FRIZQT__.TTF"))
    modPICheck:SetChecked(PWT.db.piEnabled)
    modAtCheck:SetChecked(PWT.db.atonement and PWT.db.atonement.enabled or false)
    modRadCheck:SetChecked(PWT.db.radiance and PWT.db.radiance.enabled or false)
    modVSCheck:SetChecked(PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled or false)
    modURCheck:SetChecked(PWT.db.utilityReminders and PWT.db.utilityReminders.enabled or false)
    UI:SetTabEnabled("pi",        PWT.db.piEnabled)
    UI:SetTabEnabled("atonement", PWT.db.atonement and PWT.db.atonement.enabled or false)
    UI:SetTabEnabled("radiance",  PWT.db.radiance  and PWT.db.radiance.enabled  or false)
    UI:SetTabEnabled("voidshield", PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled or false)
    UI:SetTabEnabled("utility",   PWT.db.utilityReminders and PWT.db.utilityReminders.enabled or false)
end
