-- ============================================================
--  Power Word: Toolbox  |  Core/Init.lua
--  Namespace, defaults, utilities, event dispatch, slash cmds
-- ============================================================

local ADDON_NAME, PWT = ...

-- ============================================================
--  Saved Variable Defaults
-- ============================================================

PWT.defaults = {
    piEnabled           = false,
    piMode              = "priority",
    piSequenceStickLast = false,
    piList              = {},
    piSequenceList      = {},
    debug            = false,
    debugModules     = { pi = true, atonement = true, radiance = true, ui = true },
    showChatMessages = true,
    showLoginMessage = true,
    font             = "Fonts\\FRIZQT__.TTF",
    pi = {
        glowEnabled     = true,
        glowStyle       = "overlay",
        borderThickness = 3,
        glowR           = 1.0,
        glowG           = 0.85,
        glowB           = 0.0,
        glowOpacity     = 0.55,
        glowPulse       = 0.6,
        soundEnabled    = true,
        soundIndex      = 5,
        soundVolume     = 1.0,
        soundChannel    = "SFX",
        overlayEnabled  = false,
        overlayPosX     = nil,
        overlayPosY     = nil,
        overlayFontSize = 24,
    },
    radiance = {
        enabled     = false,
        brightPupil = false,
        posX        = nil,
        posY        = nil,
        barWidth    = 220,
        barHeight   = 18,
        showTimer   = true,
        barColor    = {1.0, 0.82, 0.0},
        textColor   = {1.0, 1.0, 1.0},
    },
    atonement = {
        enabled       = false,
        showLowest    = true,
        locked        = false,
        posX          = nil,
        posY          = nil,
        countFontSize = 32,
        timerFontSize = 20,
        mouseFollow   = false,
        mouseAnchor   = "TOPLEFT",
    },
    utilityReminders = {
        enabled    = true,
        alertPosX  = nil,
        alertPosY  = nil,
        alertSize  = 18,
        checks  = {
            magisters         = { shackle = true,  purify = false, phantasm = false },
            maisara           = { shackle = true,  purify = true,  phantasm = false },
            nexuspoint        = { shackle = false, purify = false, phantasm = true  },
            windrunner        = { shackle = true,  purify = false, phantasm = false },
            algethaar         = { shackle = false, purify = false, phantasm = false },
            seatoftriumvirate = { shackle = true,  purify = false, phantasm = true  },
            skyreach          = { shackle = false, purify = false, phantasm = false },
            pitofsaron        = { shackle = true,  purify = true,  phantasm = true  },
        },
    },
}

-- ============================================================
--  Utility
-- ============================================================

function PWT:Print(msg)
    if PWT.db and PWT.db.showChatMessages == false then return end
    print("|cffcc99ffPWT|r " .. tostring(msg))
end

function PWT:Debug(msg, module)
    if not (PWT.db and PWT.db.debug) then return end
    if module then
        local mods = PWT.db.debugModules
        if mods and mods[module] == false then return end
    end
    print("|cffaaaaaa[PWT Debug" .. (module and ":" .. module or "") .. "]|r " .. tostring(msg))
end

-- ============================================================
--  Class / Spec Detection
-- ============================================================

PWT.isPriest = false
PWT.isDisc   = false

function PWT:CheckSpec()
    local _, class = UnitClass("player")
    self.isPriest = (class == "PRIEST")

    if self.isPriest then
        local specID = GetSpecializationInfo(GetSpecialization() or 0)
        self.isDisc = (specID == 256)  -- 256 = Discipline
    else
        self.isDisc = false
    end

    self:Debug("CheckSpec: isPriest=" .. tostring(self.isPriest) ..
               "  isDisc=" .. tostring(self.isDisc))

    if PWT.UI then PWT.UI:UpdateTabVisibility() end
    if not self.isDisc and PWT.Atonement then PWT.Atonement:HideWidget() end
    if not self.isDisc and PWT.Radiance  then PWT.Radiance:HideWidget()  end
end

-- ============================================================
--  Saved Variable Migration
-- ============================================================

local function MigrateDB()
    local db = PowerWordToolboxDB
    if not db.piList           then db.piList           = {} end
    if not db.piSequenceList   then db.piSequenceList   = {} end
    if db.piMode              == nil then db.piMode              = "priority" end
    if db.piSequenceStickLast == nil then db.piSequenceStickLast = false     end
    if db.piEnabled     == nil then db.piEnabled        = false end
    if db.showChatMessages == nil then db.showChatMessages = true end
    if db.showLoginMessage == nil then db.showLoginMessage = true end
    if db.debug         == nil then db.debug            = false end
    if db.font          == nil then db.font             = "Fonts\\FRIZQT__.TTF" end
    if not db.debugModules then
        db.debugModules = { pi = true, atonement = true, ui = true }
    else
        if db.debugModules.pi        == nil then db.debugModules.pi        = true end
        if db.debugModules.atonement == nil then db.debugModules.atonement = true end
        if db.debugModules.ui        == nil then db.debugModules.ui        = true end
    end

    if not db.pi then
        db.pi = CopyTable(PWT.defaults.pi)
    else
        local pi = db.pi
        if pi.glowStyle       == nil then pi.glowStyle       = "overlay" end
        if pi.borderThickness == nil then pi.borderThickness = 3 end
        if pi.glowEnabled     == nil then pi.glowEnabled     = true end
        if pi.soundEnabled    == nil then pi.soundEnabled    = true end
        if pi.soundIndex      == nil then pi.soundIndex      = 5 end
        if pi.soundVolume     == nil then pi.soundVolume     = 1.0 end
        if pi.soundChannel    == nil then pi.soundChannel    = "SFX" end
        if pi.overlayEnabled  == nil then pi.overlayEnabled  = false end
        if pi.overlayFontSize == nil then pi.overlayFontSize = 24 end
    end

    if not db.radiance then
        db.radiance = CopyTable(PWT.defaults.radiance)
    else
        local r = db.radiance
        if r.enabled     == nil then r.enabled     = false          end
        if r.brightPupil == nil then r.brightPupil = false          end
        if r.barWidth    == nil then r.barWidth    = 220             end
        if r.barHeight   == nil then r.barHeight   = 18             end
        if r.showTimer   == nil then r.showTimer   = true           end
        if r.barColor    == nil then r.barColor    = {1.0, 0.82, 0.0} end
        if r.textColor   == nil then r.textColor   = {1.0, 1.0, 1.0}  end
    end
    if db.debugModules.radiance == nil then db.debugModules.radiance = true end

    if not db.atonement then
        db.atonement = CopyTable(PWT.defaults.atonement)
    else
        local at = db.atonement
        if at.locked        == nil then at.locked        = false end
        if at.countFontSize == nil then at.countFontSize = 32 end
        if at.timerFontSize == nil then at.timerFontSize = 20 end
        if at.enabled       == nil then at.enabled       = false end
        if at.showLowest    == nil then at.showLowest     = true end
        if at.mouseFollow   == nil then at.mouseFollow   = false end
        if at.mouseAnchor   == nil then at.mouseAnchor   = "TOPLEFT" end
    end

    if not db.utilityReminders then
        db.utilityReminders = CopyTable(PWT.defaults.utilityReminders)
    else
        local ur = db.utilityReminders
        if ur.enabled   == nil then ur.enabled   = true end
        if ur.alertSize == nil then ur.alertSize  = 18   end
        ur.alertWidth = nil  -- removed in favour of alertSize
        -- Clamp in case a saved value predates the 10-100 range
        if ur.alertSize then ur.alertSize = math.max(10, math.min(100, ur.alertSize)) end
        if not ur.checks then ur.checks = CopyTable(PWT.defaults.utilityReminders.checks) end
        -- Ensure every dungeon/spell entry exists (handles new additions in future patches)
        local defChecks = PWT.defaults.utilityReminders.checks
        for dkey, defDung in pairs(defChecks) do
            if not ur.checks[dkey] then
                ur.checks[dkey] = CopyTable(defDung)
            else
                for skey, defVal in pairs(defDung) do
                    if ur.checks[dkey][skey] == nil then
                        ur.checks[dkey][skey] = defVal
                    end
                end
            end
        end
    end
end

-- ============================================================
--  Event Dispatch
-- ============================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_START")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then return end
        if not PowerWordToolboxDB then
            PowerWordToolboxDB = CopyTable(PWT.defaults)
        end
        MigrateDB()
        PWT.db = PowerWordToolboxDB
        if PWT.UI then PWT.UI:ApplyFont(PWT.db.font) end
        PWT:Debug("Saved variables loaded. piMode=" .. tostring(PWT.db.piMode) ..
            "  piList=" .. #PWT.db.piList ..
            "  seqList=" .. #PWT.db.piSequenceList)

    elseif event == "PLAYER_LOGIN" then
        PWT:CheckSpec()
        if not PWT.isPriest then
            if PWT.db.showLoginMessage then
                PWT:Print("Power Word: Toolbox is designed for Priests only.")
            end
            return
        end
        if PWT.db.showLoginMessage then
            PWT:Print("Loaded! Type |cff00ccff/pwtb|r to open options.")
        end
        if PWT.PI then PWT.PI:OnLogin() end
        if PWT.isDisc and PWT.Atonement then PWT.Atonement:OnLogin() end
        if PWT.isDisc and PWT.Radiance  then PWT.Radiance:OnLogin()  end
        if PWT.UtilityReminders then PWT.UtilityReminders:OnLogin() end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        PWT:Debug("Specialization changed, re-checking class/spec.")
        PWT:CheckSpec()
        if PWT.isDisc and PWT.Atonement then PWT.Atonement:OnLogin() end
        if PWT.isDisc and PWT.Radiance  then PWT.Radiance:OnLogin()  end

    elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        PWT:Debug("Talent event fired: " .. event, "radiance")
        if PWT.isDisc and PWT.Radiance then PWT.Radiance:DetectBrightPupil() end

    elseif event == "CHAT_MSG_WHISPER" then
        if not PWT.isPriest then return end
        if PWT.PI then PWT.PI:OnWhisper() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not PWT.isPriest then return end
        local unit, _, spellID = ...
        if PWT.PI then PWT.PI:OnSpellCast(unit, spellID) end
        if PWT.isDisc and PWT.Radiance then PWT.Radiance:OnSpellCast(unit, spellID) end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if not PWT.isPriest then return end
        if PWT.PI then PWT.PI:OnLeaveCombat() end

    elseif event == "UNIT_AURA" then
        if not PWT.isDisc then return end
        local unit = ...
        if PWT.Atonement then PWT.Atonement:ScanUnit(unit) end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if PWT.isDisc and PWT.Atonement then
            PWT:Debug("Group roster changed, rescanning Atonement.")
            PWT.Atonement:ScanAll()
        end

    elseif event == "ENCOUNTER_START" then
        if PWT.PI then PWT.PI:OnEncounterStart() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if PWT.isDisc and PWT.Atonement then
            PWT:Debug("Entering world, rescanning Atonement.")
            PWT.Atonement:ScanAll()
        end
        if PWT.UtilityReminders then
            -- Delay slightly so GetInstanceInfo() returns stable data
            C_Timer.After(3, function()
                if PWT.UtilityReminders then
                    PWT.UtilityReminders:TriggerCheck()
                end
            end)
        end
    end
end)

-- ============================================================
--  Slash Commands
-- ============================================================

SLASH_PWTB1 = "/pwtb"
SLASH_PWTB2 = "/powerwordtoolbox"
SLASH_PWTB3 = "/ptw"
SLASH_PWTB4 = "/pwt"

SlashCmdList["PWTB"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "debug" then
        PWT.db.debug = not PWT.db.debug
        PWT:Print("Debug mode: " .. (PWT.db.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))

    elseif cmd == "status" then
        local _, class  = UnitClass("player")
        local specIndex = GetSpecialization() or 0
        local specID    = specIndex > 0 and GetSpecializationInfo(specIndex) or 0
        local LSM       = LibStub and LibStub("LibSharedMedia-3.0", true)
        PWT:Print("=== Power Word: Toolbox Status ===")
        PWT:Print("Version: |cffcc99ffv1.0.0|r")
        PWT:Print("Class: " .. tostring(class) ..
            "  isPriest=" .. tostring(PWT.isPriest) ..
            "  isDisc="   .. tostring(PWT.isDisc) ..
            "  specID="   .. tostring(specID))
        if PWT.PI then PWT.PI:PrintStatus() end
        if PWT.Radiance  then PWT.Radiance:PrintStatus()  end
        if PWT.Atonement then PWT.Atonement:PrintStatus() end
        PWT:Print("LibSharedMedia: " ..
            (LSM and "|cff00ff00available|r" or "|cffff4444not found|r"))
        PWT:Print("Raid frames: Grid2="    .. tostring(Grid2Frame ~= nil) ..
            "  Danders=" .. tostring(DandersFrames ~= nil) ..
            "  Cell="    .. tostring(Cell ~= nil) ..
            "  ElvUI="   .. tostring(ElvUF_Parent ~= nil) ..
            "  Blizzard=" .. tostring(CompactRaidFrameContainer ~= nil))
        PWT:Print("Group: inRaid=" .. tostring(IsInRaid()) ..
            "  members=" .. GetNumGroupMembers())
        PWT:Print("================================")

    elseif cmd == "reset" then
        if PWT.UI then PWT.UI:ResetPosition() end

    elseif cmd == "seqreset" then
        if PWT.PI then PWT.PI:ResetSequence() end
        PWT:Print("PI sequence reset to position 1.")

    elseif cmd == "spellcheck" then
        if PWT.PI then PWT.PI:PrintCooldownState() end

    elseif cmd == "rdebug" then
        if PWT.Radiance then
            PWT.Radiance:SetDebugCasts(not PWT.Radiance.debugCasts)
            PWT:Print("Radiance cast debug: " ..
                (PWT.Radiance.debugCasts and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        end

    elseif cmd == "help" then
        PWT:Print("=== Power Word: Toolbox Commands ===")
        PWT:Print("|cff00ccff/pwtb|r — open options")
        PWT:Print("|cff00ccff/pwtb debug|r — toggle debug mode")
        PWT:Print("|cff00ccff/pwtb rdebug|r — toggle Radiance cast event debug logging")
        PWT:Print("|cff00ccff/pwtb status|r — print full addon state")
        PWT:Print("|cff00ccff/pwtb spellcheck|r — check PI cooldown state")
        PWT:Print("|cff00ccff/pwtb seqreset|r — reset PI sequence to position 1")
        PWT:Print("|cff00ccff/pwtb reset|r — recentre options window")

    else
        if PWT.UI then PWT.UI:Toggle() end
    end
end
