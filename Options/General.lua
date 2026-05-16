-- Power Word: Toolbox | Options/General.lua

local _, PWT = ...
local UI        = PWT.UI
local C         = UI.C
local PAD       = UI.PAD
local CONTENT_W = UI.CONTENT_W

local generalPanel = UI:AddTab("general", "General", 1)

local genScroll = CreateFrame("ScrollFrame", nil, generalPanel)
genScroll:SetAllPoints(generalPanel)
genScroll:EnableMouseWheel(true)
genScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
end)

local genContent = CreateFrame("Frame", nil, genScroll)
genContent:SetWidth(CONTENT_W)
genContent:SetHeight(480)
genScroll:SetScrollChild(genContent)

-- ── Modules ───────────────────────────────────────────────────────────────

local modulesHdr = UI:MakeSectionHeader(genContent, genContent, 0, "Modules")
modulesHdr:ClearAllPoints()
modulesHdr:SetPoint("TOPLEFT",  genContent, "TOPLEFT",  0, -PAD)
modulesHdr:SetPoint("TOPRIGHT", genContent, "TOPRIGHT", -PAD, 0)

-- 2×2 grid layout
local COL_W   = math.floor((CONTENT_W - PAD) / 2) - PAD
local COL_GAP = PAD
local ROW_GAP = 8

local modPICheck = UI:MakeCheckbox(genContent, "Power Infusion", nil, function(val)
    PWT.db.piEnabled = val
    UI:SetTabEnabled("pi", val)
end)
modPICheck:SetPoint("TOPLEFT", modulesHdr, "BOTTOMLEFT", 0, -10)
modPICheck:SetWidth(COL_W)
modPICheck.lbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "")

local modAtCheck = UI:MakeCheckbox(genContent, "Atonement Tracker", nil, function(val)
    PWT.db.atonement.enabled = val
    if val then
        if PWT.Atonement then PWT.Atonement:UpdateWidget(); PWT.Atonement:ScanAll() end
    else
        if PWT.Atonement then PWT.Atonement:HideWidget() end
    end
    UI:SetTabEnabled("atonement", val)
end)
modAtCheck:SetPoint("TOPLEFT", modulesHdr, "BOTTOMLEFT", COL_W + COL_GAP, -10)
modAtCheck:SetWidth(COL_W)
modAtCheck.lbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "")

local modRadCheck = UI:MakeCheckbox(genContent, "Radiance Bars", nil, function(val)
    if not PWT.db.radiance then PWT.db.radiance = {} end
    PWT.db.radiance.enabled = val
    if val then
        if PWT.isDisc and PWT.Radiance then PWT.Radiance:ShowWidget() end
    else
        if PWT.Radiance then PWT.Radiance:HideWidget() end
    end
    UI:SetTabEnabled("radiance", val)
end)
modRadCheck:SetPoint("TOPLEFT", modPICheck, "BOTTOMLEFT", 0, -ROW_GAP)
modRadCheck:SetWidth(COL_W)
modRadCheck.lbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "")

local modVSCheck = UI:MakeCheckbox(genContent, "Void Shield Deck", nil, function(val)
    if not PWT.db.voidShieldDeck then PWT.db.voidShieldDeck = {} end
    PWT.db.voidShieldDeck.enabled = val
    if val then
        if PWT.isDisc and PWT.VoidShieldDeck then
            PWT.VoidShieldDeck:EnterUnknownState("module enabled")
            PWT.VoidShieldDeck:ShowWidget()
        end
    else
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:HideWidget() end
    end
    UI:SetTabEnabled("voidshield", val)
end)
modVSCheck:SetPoint("TOPLEFT", modAtCheck, "BOTTOMLEFT", 0, -ROW_GAP)
modVSCheck:SetWidth(COL_W)
modVSCheck.lbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "")

local genLine1 = UI:MakeLine(genContent, C.border, 1)
genLine1:SetPoint("TOPLEFT",  modRadCheck, "BOTTOMLEFT",  0, -12)
genLine1:SetPoint("TOPRIGHT", genContent,  "TOPRIGHT", -PAD, -12)

-- ── Settings ──────────────────────────────────────────────────────────────

local settingsHdr = UI:MakeSectionHeader(genContent, genLine1, -10, "Settings")

local SETTING_LABEL_W = 110   -- fixed label column width for alignment

local SOUND_CHANNELS = {
    { label = "SFX (Default)", value = "SFX"      },
    { label = "Master",        value = "Master"    },
    { label = "Music",         value = "Music"     },
    { label = "Ambience",      value = "Ambience"  },
    { label = "Dialog",        value = "Dialog"    },
}

local function GetChannelLabel(value)
    for _, e in ipairs(SOUND_CHANNELS) do
        if e.value == value then return e.label end
    end
    return "SFX (Default)"
end

local chanDD
chanDD = UI:MakeDropdown(genContent, SOUND_CHANNELS,
    function(entry)
        if PWT.db then
            if PWT.db.pi             then PWT.db.pi.soundChannel                 = entry.value end
            if PWT.db.voidShieldDeck then PWT.db.voidShieldDeck.procSoundChannel = entry.value end
        end
        chanDD.setLabel(entry.label)
    end,
    {
        width       = 180,
        popupW      = 210,
        popupH      = 108,
        rowH        = 20,
        getSelected = function() return (PWT.db and PWT.db.pi and PWT.db.pi.soundChannel) or "SFX" end,
    })

local chanLbl = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
chanLbl:SetWidth(SETTING_LABEL_W)
chanLbl:SetJustifyH("LEFT")
chanLbl:SetPoint("TOPLEFT", settingsHdr, "BOTTOMLEFT", 0, -10)
chanLbl:SetText("Audio Channel:")
chanLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
chanDD.button:SetPoint("LEFT", chanLbl, "RIGHT", 8, 0)

-- Interface Font — row anchored to chanDD.button bottom so rows never overlap
local BUILTIN_FONTS = {
    { label = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF" },
    { label = "Arial Narrow",            path = "Fonts\\ARIALN.TTF"   },
    { label = "Morpheus",                path = "Fonts\\MORPHEUS.TTF" },
    { label = "Skurri",                  path = "Fonts\\SKURRI.TTF"   },
}

local fontList = {}

local function BuildFontList()
    wipe(fontList)
    for _, f in ipairs(BUILTIN_FONTS) do
        fontList[#fontList + 1] = { label = f.label, path = f.path, value = f.path }
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
                    fontList[#fontList + 1] = { label = name, path = path, value = path }
                    seen[path] = true
                end
            end
        end
    end
    return fontList
end

local function GetFontLabel(path)
    for _, e in ipairs(fontList)      do if e.path == path then return e.label end end
    for _, e in ipairs(BUILTIN_FONTS) do if e.path == path then return e.label end end
    return "Friz Quadrata (Default)"
end

local fontDD
fontDD = UI:MakeDropdown(genContent,
    function() BuildFontList(); return fontList end,
    function(entry)
        PWT.db.font = entry.path
        fontDD.setLabel(entry.label)
        UI:ApplyFont(entry.path)
    end,
    {
        width       = 180,
        popupW      = 210,
        popupH      = 200,
        rowH        = 20,
        getSelected = function() return (PWT.db and PWT.db.font) or "Fonts\\FRIZQT__.TTF" end,
        renderRow   = function(row, entry, isSelected)
            local rowLbl = row:CreateFontString(nil, "OVERLAY")
            rowLbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
            rowLbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            rowLbl:SetJustifyH("LEFT")
            if not pcall(function() rowLbl:SetFont(entry.path, 12, "") end) then
                rowLbl:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
            end
            rowLbl:SetText(entry.label)
            if isSelected then
                row.bg:SetColorTexture(C.tabActive[1], C.tabActive[2], C.tabActive[3], 0.8)
                rowLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
            else
                row.bg:SetColorTexture(0, 0, 0, 0)
                rowLbl:SetTextColor(C.text[1], C.text[2], C.text[3])
            end
            row:SetScript("OnEnter", function(self)
                if entry.path ~= (PWT.db and PWT.db.font) then
                    self.bg:SetColorTexture(C.tabHover[1], C.tabHover[2], C.tabHover[3], 0.6)
                end
            end)
            row:SetScript("OnLeave", function(self)
                local active = (entry.path == (PWT.db and PWT.db.font))
                self.bg:SetColorTexture(
                    active and C.tabActive[1] or 0, active and C.tabActive[2] or 0,
                    active and C.tabActive[3] or 0, active and C.tabActive[4] or 0)
            end)
        end,
    })

-- fontLbl anchored to chanDD.button BOTTOMLEFT so rows never touch
local fontLbl = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
fontLbl:SetWidth(SETTING_LABEL_W)
fontLbl:SetJustifyH("LEFT")
fontLbl:SetPoint("TOPLEFT", chanDD.button, "BOTTOMLEFT", -(SETTING_LABEL_W + 8), -10)
fontLbl:SetText("Interface Font:")
fontLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
fontDD.button:SetPoint("LEFT", fontLbl, "RIGHT", 8, 0)

-- ── Slash Commands ────────────────────────────────────────────────────────

local genLine2 = UI:MakeLine(genContent, C.border, 1)
genLine2:SetPoint("TOPLEFT",  fontDD.button, "BOTTOMLEFT", -(SETTING_LABEL_W + 8), -12)
genLine2:SetPoint("TOPRIGHT", genContent, "TOPRIGHT", -PAD, -12)

local slashHdr = UI:MakeSectionHeader(genContent, genLine2, -10, "Slash Commands")

local SLASH_CMDS = {
    { cmd = "/pwtb",          desc = "Open this options window"                    },
    { cmd = "/pwtb reset",    desc = "Re-centre the options window"                },
    { cmd = "/pwtb vsguide",  desc = "Show Void Shield Deck Guide"                 },
    { cmd = "/pwtb debug",    desc = "Toggle debug mode"                           },
}

local CMD_W = 120
local prevRow
for i, entry in ipairs(SLASH_CMDS) do
    local cmdLbl = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    cmdLbl:SetWidth(CMD_W)
    cmdLbl:SetJustifyH("LEFT")
    cmdLbl:SetTextColor(C.textAccent[1], C.textAccent[2], C.textAccent[3])
    cmdLbl:SetText(entry.cmd)

    local descLbl = genContent:CreateFontString(nil, "OVERLAY", "PWT_FontSmall")
    descLbl:SetJustifyH("LEFT")
    descLbl:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    descLbl:SetText(entry.desc)

    if i == 1 then
        cmdLbl:SetPoint("TOPLEFT", slashHdr, "BOTTOMLEFT", 0, -8)
    else
        cmdLbl:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, -6)
    end
    descLbl:SetPoint("LEFT",  cmdLbl, "RIGHT", 12, 0)
    descLbl:SetPoint("RIGHT", genContent, "RIGHT", -PAD, 0)

    prevRow = cmdLbl
end

-- ── Sync ──────────────────────────────────────────────────────────────────

function UI:SyncGeneral()
    if not PWT.db then return end
    local chanVal = (PWT.db.pi and PWT.db.pi.soundChannel) or "SFX"
    chanDD.setLabel(GetChannelLabel(chanVal))
    BuildFontList()
    fontDD.setLabel(GetFontLabel(PWT.db.font or "Fonts\\FRIZQT__.TTF"))
    modPICheck.set(PWT.db.piEnabled)
    modAtCheck.set(PWT.db.atonement     and PWT.db.atonement.enabled     or false)
    modRadCheck.set(PWT.db.radiance      and PWT.db.radiance.enabled      or false)
    modVSCheck.set(PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled or false)
    UI:SetTabEnabled("pi",         PWT.db.piEnabled)
    UI:SetTabEnabled("atonement",  PWT.db.atonement     and PWT.db.atonement.enabled     or false)
    UI:SetTabEnabled("radiance",   PWT.db.radiance       and PWT.db.radiance.enabled       or false)
    UI:SetTabEnabled("voidshield", PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled or false)
end
