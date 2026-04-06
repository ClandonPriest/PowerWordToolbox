-- ============================================================
--  Power Word: Toolbox  |  Options/UI.lua
--  Options frame shell: window, title bar, tab system,
--  shared colour palette and helper functions.
--  Individual tab content is in the other Options/ files.
-- ============================================================

local _, PWT = ...

PWT.UI = {}
local UI = PWT.UI

-- ============================================================
--  Layout Constants (shared by all Options/ files)
-- ============================================================

UI.FRAME_W   = 460
UI.FRAME_H   = 600
UI.PAD       = 16
UI.TITLE_H   = 36
UI.TAB_BAR_H = 36
UI.FOOTER_H  = 44
UI.CONTENT_Y = UI.TITLE_H + UI.TAB_BAR_H

-- ============================================================
--  Colour Palette (shared by all Options/ files)
-- ============================================================

UI.C = {
    bg         = {0.08, 0.08, 0.10, 0.97},
    titleBar   = {0.10, 0.10, 0.13, 1.00},
    tabBar     = {0.06, 0.06, 0.08, 1.00},
    tabActive  = {0.18, 0.18, 0.22, 1.00},
    tabHover   = {0.14, 0.14, 0.17, 1.00},
    accent     = {0.80, 0.60, 1.00, 1.00},
    border     = {0.25, 0.20, 0.35, 0.80},
    rowEven    = {0.11, 0.11, 0.14, 0.80},
    rowOdd     = {0.08, 0.08, 0.10, 0.50},
    footerBg   = {0.06, 0.06, 0.08, 1.00},
    text       = {0.90, 0.88, 0.95, 1.00},
    textMuted  = {0.55, 0.52, 0.60, 1.00},
    textAccent = {0.80, 0.60, 1.00, 1.00},
    danger     = {0.90, 0.30, 0.30, 1.00},
    success    = {0.30, 0.90, 0.50, 1.00},
}

-- ============================================================
--  Shared Drawing Helpers
-- ============================================================

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

-- ============================================================
--  Addon Font Objects  (overrideable via General tab font selector)
-- ============================================================

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
    if PWT.Atonement then PWT.Atonement:UpdateWidget() end
    if PWT.PI       then PWT.PI:UpdateOverlayFont()   end
end

-- ============================================================
--  Tab System
-- ============================================================

local tabDisabledState = {}
local tabs      = {}
local tabPanels = {}
local activeTab = nil
UI.tabs      = tabs
UI.tabPanels = tabPanels

local TAB_W = 90
local TAB_H  -- set after TAB_BAR_H is known

local function SwitchTab(name)
    if tabDisabledState[name] then return end
    activeTab = name
    local C = UI.C

    -- Hide PI floating controls first (SyncPI will re-show them when name == "pi")
    if UI.piFooterControls  then UI.piFooterControls:Hide() end
    if UI.modePriorityBtn   then UI.modePriorityBtn:Hide() end
    if UI.modeSequenceBtn   then UI.modeSequenceBtn:Hide() end
    if UI.seqIndexLabel     then UI.seqIndexLabel:Hide()   end

    for tabName, tab in pairs(tabs) do
        local isActive = (tabName == name)
        if isActive then
            tab.bg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
            tab.label:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            tab.accent:Show()
        elseif not tabDisabledState[tabName] then
            tab.bg:SetColorTexture(C.tabBar[1], C.tabBar[2], C.tabBar[3], C.tabBar[4])
            tab.label:SetTextColor(0.78, 0.75, 0.85, 1.0)
            tab.accent:Hide()
        end
        -- disabled tabs: leave their visual state untouched
    end
    for panelName, panel in pairs(tabPanels) do
        if panelName == name then panel:Show() else panel:Hide() end
    end

    -- Notify each tab module to sync its controls.
    -- SyncPI is responsible for re-showing the PI footer/mode buttons.
    if name == "general"    and UI.SyncGeneral           then UI:SyncGeneral() end
    if name == "pi"         and UI.SyncPI                then UI:SyncPI() end
    if name == "atonement"  and UI.SyncAtonement         then UI:SyncAtonement() end
    if name == "radiance"   and UI.SyncRadiance          then UI:SyncRadiance() end
    if name == "utility"    and UI.SyncUtilityReminders  then UI:SyncUtilityReminders() end
end
UI.SwitchTab = SwitchTab

function UI:AddTab(name, label, index)
    local C  = self.C
    TAB_H    = TAB_H or (self.TAB_BAR_H - 4)
    local tab = CreateFrame("Button", nil, self.tabBar)
    tab:SetSize(TAB_W, TAB_H)
    tab:SetPoint("LEFT", self.tabBar, "LEFT", (index - 1) * TAB_W + 4, 0)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints(tab)
    tab.bg:SetColorTexture(C.tabBar[1], C.tabBar[2], C.tabBar[3], C.tabBar[4])

    tab.accent = tab:CreateTexture(nil, "OVERLAY")
    tab.accent:SetHeight(2)
    tab.accent:SetPoint("BOTTOMLEFT",  tab, "BOTTOMLEFT",  4, 0)
    tab.accent:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
    tab.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    tab.accent:Hide()

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.label:SetText(label)
    tab.label:SetTextColor(0.78, 0.75, 0.85, 1.0)  -- readable-but-inactive (brighter than textMuted)

    tab:SetScript("OnClick", function() SwitchTab(name) end)
    tab:SetScript("OnEnter", function(self)
        if tabDisabledState[name] then return end
        if activeTab ~= name then
            self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], C.tabHover[4])
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if tabDisabledState[name] then return end
        if activeTab ~= name then
            self.bg:SetColorTexture(C.tabBar[1], C.tabBar[2], C.tabBar[3], C.tabBar[4])
            self.label:SetTextColor(0.78, 0.75, 0.85, 1.0)
        end
    end)

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
    local C = UI.C
    tabDisabledState[name] = not enabled
    if enabled then
        local isActive = (activeTab == name)
        if isActive then
            tab.bg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
            tab.label:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            tab.accent:Show()
        else
            tab.bg:SetColorTexture(C.tabBar[1], C.tabBar[2], C.tabBar[3], C.tabBar[4])
            tab.label:SetTextColor(0.78, 0.75, 0.85, 1.0)
            tab.accent:Hide()
        end
    else
        -- Disabled: dark red-tinted background, dim text.
        tab.bg:SetColorTexture(0.09, 0.05, 0.05, 1.0)
        tab.label:SetTextColor(0.52, 0.34, 0.34, 1.0)
        tab.accent:Hide()
        if activeTab == name then
            SwitchTab("general")
        end
    end
end

function UI:UpdateTabVisibility()
    if tabs["pi"] then
        tabs["pi"]:SetShown(PWT.isPriest)
    end
    if tabs["atonement"] then
        tabs["atonement"]:SetShown(PWT.isDisc)
    end
    if tabs["radiance"] then
        tabs["radiance"]:SetShown(PWT.isDisc)
    end
end

-- ============================================================
--  Window Construction
-- ============================================================

local optionsFrame = CreateFrame("Frame", "PowerWordToolboxOptions", UIParent)
UI.optionsFrame = optionsFrame

local C = UI.C
local PAD      = UI.PAD
local TITLE_H  = UI.TITLE_H
local TAB_BAR_H_val = UI.TAB_BAR_H
local FOOTER_H = UI.FOOTER_H
local CONTENT_Y = UI.CONTENT_Y
local FRAME_W  = UI.FRAME_W
local FRAME_H  = UI.FRAME_H

optionsFrame:SetSize(FRAME_W, FRAME_H)
optionsFrame:SetPoint("CENTER")
table.insert(UISpecialFrames, "PowerWordToolboxOptions")
optionsFrame:SetMovable(true)
optionsFrame:SetClampedToScreen(true)
optionsFrame:EnableMouse(true)
optionsFrame:RegisterForDrag("LeftButton")
optionsFrame:SetScript("OnDragStart", function(self)
    if PWT_FontDropPanel then PWT_FontDropPanel:Hide() end
    self:StartMoving()
end)
optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
optionsFrame:SetScript("OnMouseDown", function()
    if PWT_FontDropPanel then PWT_FontDropPanel:Hide() end
end)
optionsFrame:SetFrameStrata("DIALOG")
optionsFrame:SetResizable(true)
optionsFrame:SetResizeBounds(360, 500)
optionsFrame:Hide()

-- Resize grip — parented to UIParent so footer/piFooterControls frames can never sit above it
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
        -- Anchor to BOTTOMLEFT of UIParent: GetLeft() and GetTop() are both measured
        -- from the screen's bottom-left, so this avoids any subtraction with GetHeight().
        local x = optionsFrame:GetLeft()
        local y = optionsFrame:GetTop()
        optionsFrame:ClearAllPoints()
        optionsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        optionsFrame:StartSizing("BOTTOMRIGHT")
    end
end)
resizeGrip:SetScript("OnMouseUp", function() optionsFrame:StopMovingOrSizing() end)
-- Hide the grip when the options frame is hidden
optionsFrame:HookScript("OnHide", function() resizeGrip:Hide() end)
optionsFrame:HookScript("OnShow", function() resizeGrip:Show() end)
resizeGrip:Hide()  -- starts hidden; shown when optionsFrame opens
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

-- Title bar
local titleBar = CreateFrame("Frame", nil, optionsFrame)
titleBar:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, 0)
titleBar:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, 0)
titleBar:SetHeight(TITLE_H)
UI:MakeBg(titleBar, C.titleBar)
local titleAccent = UI:MakeLine(optionsFrame, C.accent, 2)
titleAccent:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, -TITLE_H)
titleAccent:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, -TITLE_H)
local titleText = titleBar:CreateFontString(nil, "OVERLAY", "PWT_FontLarge")
titleText:SetPoint("LEFT", titleBar, "LEFT", PAD, 0)
titleText:SetText("|cffcc99ffPower Word:|r Toolbox")
local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
closeBtn:SetSize(28, 28)
closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)

local resetWinBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
resetWinBtn:SetSize(60, 20)
resetWinBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
resetWinBtn:SetText("Reset")
resetWinBtn:SetScript("OnClick", function() UI:ResetPosition() end)
resetWinBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Reset window position and size to default")
    GameTooltip:Show()
end)
resetWinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Tab bar
local tabBar = CreateFrame("Frame", nil, optionsFrame)
tabBar:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, -TITLE_H - 2)
tabBar:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, -TITLE_H - 2)
tabBar:SetHeight(TAB_BAR_H_val)
UI:MakeBg(tabBar, C.tabBar)
UI.tabBar = tabBar
local tabBarLine = UI:MakeLine(optionsFrame, C.border, 1)
tabBarLine:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, -(TITLE_H + TAB_BAR_H_val + 2))
tabBarLine:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, -(TITLE_H + TAB_BAR_H_val + 2))

-- Content area
local contentArea = CreateFrame("Frame", nil, optionsFrame)
contentArea:SetPoint("TOPLEFT",     optionsFrame, "TOPLEFT",     0, -(CONTENT_Y + 3))
contentArea:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", 0, FOOTER_H)
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
footerVersion:SetText("v1.0.0")
footerVersion:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

-- ============================================================
--  Public API
-- ============================================================

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
        optionsFrame:Show()
    end
end

local function CloseFontDropdown()
    if PWT_FontDropPanel then PWT_FontDropPanel:Hide() end
end

function UI:ResetPosition()
    CloseFontDropdown()
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
    SwitchTab(activeTab or "general")
end)
