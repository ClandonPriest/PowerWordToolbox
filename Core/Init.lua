-- Power Word: Toolbox | Core/Init.lua

local ADDON_NAME, PWT = ...

-- Saved Variable Defaults

PWT.defaults = {
    piEnabled           = false,
    piMode              = "priority",
    piSequenceStickLast = false,
    piList              = {},
    piSequenceList      = {},
    debug            = false,
    debugModules     = { pi = true, atonement = true, radiance = true, ui = true, voidshield = true, utility = true },
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
        soundChannel    = "SFX",
        overlayEnabled       = false,
        overlayPosX          = nil,
        overlayPosY          = nil,
        overlayFontSize      = 24,
        earlyRequestEnabled  = true,
        earlyRequestWindow   = 5,
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
    voidShieldDeck = {
        enabled        = false,
        chancePosX     = nil,
        chancePosY     = nil,
        deckPosX       = nil,
        deckPosY       = nil,
        cardsPosX      = nil,
        cardsPosY      = nil,
        showCards        = true,
        cardsRotated     = false,
        showChance       = true,
        showDeck         = true,
        showChanceLabel  = true,
        showDeckLabel    = true,
        chanceFontSize   = 18,
        deckFontSize     = 18,
        cardsSize        = 18,
        chanceStrata     = "MEDIUM",
        deckStrata       = "MEDIUM",
        cardsStrata      = "MEDIUM",
        cardProcColor    = {0.15, 0.75, 0.25},
        cardNoProcColor  = {0.80, 0.15, 0.15},
        cardUnknownColor = {0.55, 0.52, 0.60},
        -- Proc icon alert
        procAlertEnabled = false,
        procAlertPosX    = nil,
        procAlertPosY    = nil,
        procAlertSize    = 64,
        procAlertStrata  = "HIGH",
        -- Proc sound alert
        procSoundEnabled = false,
        procSoundIndex   = 5,
        procSoundChannel = "SFX",
        -- Reload state persistence (written on PLAYER_LOGOUT, consumed on reload)
        savedCardsRemaining = nil,
        savedProcAvailable  = nil,
        savedCastHistory    = nil,
        -- savedWorldX/Y/instanceID written by SaveState (UnitPosition), read by OnEnteringWorld
        savedWorldX     = nil,
        savedWorldY     = nil,
        savedInstanceID = nil,
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
}

-- Utility

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

-- Class / Spec Detection

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
    if not self.isDisc and PWT.VoidShieldDeck then PWT.VoidShieldDeck:HideWidget() end
end

-- Saved Variable Migration

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
        if db.debugModules.voidshield == nil then db.debugModules.voidshield = true end
        if db.debugModules.utility   == nil then db.debugModules.utility   = true end
    end

    if not db.pi then
        db.pi = CopyTable(PWT.defaults.pi)
    else
        local pi = db.pi
        if pi.glowStyle       == nil then pi.glowStyle       = "overlay" end
        if pi.borderThickness == nil then pi.borderThickness = 3 end
        if pi.glowEnabled     == nil then pi.glowEnabled     = true end
        if pi.glowR           == nil then pi.glowR           = 1.0  end
        if pi.glowG           == nil then pi.glowG           = 0.85 end
        if pi.glowB           == nil then pi.glowB           = 0.0  end
        if pi.glowOpacity     == nil then pi.glowOpacity     = 0.55 end
        if pi.glowPulse       == nil then pi.glowPulse       = 0.6  end
        if pi.soundEnabled    == nil then pi.soundEnabled    = true end
        if pi.soundIndex      == nil then pi.soundIndex      = 5 end
        if pi.soundChannel    == nil then pi.soundChannel    = "SFX" end
        pi.soundVolume = nil
        if pi.overlayEnabled      == nil then pi.overlayEnabled      = false end
        if pi.overlayFontSize     == nil then pi.overlayFontSize     = 24    end
        if pi.earlyRequestEnabled == nil then pi.earlyRequestEnabled = true end
        if pi.earlyRequestWindow  == nil then pi.earlyRequestWindow  = 5     end
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

    if not db.voidShieldDeck then
        db.voidShieldDeck = CopyTable(PWT.defaults.voidShieldDeck)
    else
        local vs = db.voidShieldDeck
        if vs.enabled    == nil then vs.enabled    = false end
        vs.patternResync = nil  -- baked in, no longer a user setting
        if vs.showCards       == nil then vs.showCards       = true  end
        if vs.cardsRotated    == nil then vs.cardsRotated    = false end
        if vs.showChance      == nil then vs.showChance      = true end
        if vs.showDeck        == nil then vs.showDeck        = true end
        if vs.showChanceLabel == nil then vs.showChanceLabel = true end
        if vs.showDeckLabel   == nil then vs.showDeckLabel   = true end
        -- fontSize was split into per-widget sizes; migrate old value then drop key
        if vs.chanceFontSize == nil then vs.chanceFontSize = vs.fontSize or 18 end
        if vs.deckFontSize   == nil then vs.deckFontSize   = vs.fontSize or 18 end
        vs.fontSize = nil
        if vs.cardsSize        == nil then vs.cardsSize        = 18      end
        if vs.chanceStrata     == nil then vs.chanceStrata     = "MEDIUM" end
        if vs.deckStrata       == nil then vs.deckStrata       = "MEDIUM" end
        if vs.cardsStrata      == nil then vs.cardsStrata      = "MEDIUM" end
        if vs.cardProcColor    == nil then vs.cardProcColor    = {0.15, 0.75, 0.25} end
        if vs.cardNoProcColor  == nil then vs.cardNoProcColor  = {0.80, 0.15, 0.15} end
        if vs.cardUnknownColor == nil then vs.cardUnknownColor = {0.55, 0.52, 0.60} end
        if vs.procAlertEnabled == nil then vs.procAlertEnabled = false    end
        if vs.procAlertSize    == nil then vs.procAlertSize    = 64       end
        if vs.procAlertStrata  == nil then vs.procAlertStrata  = "HIGH"   end
        if vs.procSoundEnabled == nil then vs.procSoundEnabled = false    end
        if vs.procSoundIndex   == nil then vs.procSoundIndex   = 5        end
        if vs.procSoundChannel == nil then vs.procSoundChannel = "SFX"    end
        vs.procSoundVolume = nil
        -- savedCardsRemaining/savedProcAvailable/savedCastHistory/savedMapID/savedX/savedY
        -- intentionally left nil here; written by SaveState, consumed by OnEnteringWorld.
        -- posX/posY were replaced by per-element positions; remove legacy keys
        vs.posX = nil
        vs.posY = nil
    end

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

end

-- Event Dispatch

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
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("WORLD_STATE_TIMER_START")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_CAMPING")

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
            PWT:Print("Loaded! Type |cff00ccff/pwtb|r to open options, or |cff00ccff/pwt help|r for commands.")
        end
        if PWT.db.debug and PWT.db.debugModules and PWT.db.debugModules.voidshield then
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                local mapInfo = C_Map.GetMapInfo(mapID)
                local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                if pos and mapInfo then
                    local x, y = pos:GetXY()
                    PWT:Debug(string.format("Player coordinates: %.1f%%, %.1f%% on %s", x * 100, y * 100, mapInfo.name), "voidshield")
                end
            end
        end
        if PWT.PI then PWT.PI:OnLogin() end
        if PWT.isDisc and PWT.Atonement then PWT.Atonement:OnLogin() end
        if PWT.isDisc and PWT.Radiance  then PWT.Radiance:OnLogin()  end
        if PWT.isDisc and PWT.VoidShieldDeck then PWT.VoidShieldDeck:OnLogin() end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        PWT:Debug("Specialization changed, re-checking class/spec.")
        PWT:CheckSpec()
        if PWT.isDisc and PWT.Atonement and PWT.db and PWT.db.atonement and PWT.db.atonement.enabled then
            PWT.Atonement:OnLogin()
        end
        if PWT.isDisc and PWT.Radiance  then PWT.Radiance:OnLogin()  end
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:OnSpecChange() end

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
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:OnSpellCast(unit, spellID) end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if not PWT.isPriest then return end
        if PWT.PI then PWT.PI:OnLeaveCombat() end

    elseif event == "UNIT_AURA" then
        if not PWT.isDisc then return end
        if not (PWT.db and PWT.db.atonement and PWT.db.atonement.enabled) then return end
        local unit = ...
        if PWT.Atonement then PWT.Atonement:ScanUnit(unit) end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if PWT.isDisc and PWT.Atonement
           and PWT.db and PWT.db.atonement and PWT.db.atonement.enabled then
            PWT:Debug("Group roster changed, rescanning Atonement.")
            PWT.Atonement:ScanAll()
        end

    elseif event == "ENCOUNTER_START" then
        if PWT.PI then PWT.PI:OnEncounterStart() end
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:OnEncounterStart() end

    elseif event == "CHALLENGE_MODE_START" then
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:OnChallengeModeArmed() end

    elseif event == "WORLD_STATE_TIMER_START" then
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:OnChallengeModeStart() end

    elseif event == "PLAYER_CAMPING" then
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:SaveState() end

    elseif event == "PLAYER_LOGOUT" then
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:SaveState() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, isReload = ...
        if PWT.isDisc and PWT.VoidShieldDeck then
            PWT.VoidShieldDeck:OnEnteringWorld(isReload)
        end
        if PWT.isDisc and PWT.Atonement
           and PWT.db and PWT.db.atonement and PWT.db.atonement.enabled then
            PWT:Debug("Entering world, rescanning Atonement.")
            PWT.Atonement:ScanAll()
        end
    end
end)

-- Slash Commands

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
        PWT:Print("Version: |cffcc99ffv" .. (C_AddOns.GetAddOnMetadata("PowerWordToolbox", "Version") or "?") .. "|r")
        PWT:Print("Class: " .. tostring(class) ..
            "  isPriest=" .. tostring(PWT.isPriest) ..
            "  isDisc="   .. tostring(PWT.isDisc) ..
            "  specID="   .. tostring(specID))
        if PWT.PI then PWT.PI:PrintStatus() end
        if PWT.Radiance  then PWT.Radiance:PrintStatus()  end
        if PWT.Atonement then PWT.Atonement:PrintStatus() end
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:PrintStatus() end
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

    elseif cmd == "coords" then
        local vs = PWT.db and PWT.db.voidShieldDeck
        local posY, posX, _, instanceID = UnitPosition("player")
        if vs and vs.savedWorldX then
            PWT:Print(string.format("Saved position:   x=%.1f y=%.1f instance=%s", vs.savedWorldX, vs.savedWorldY or 0, tostring(vs.savedInstanceID or 0)))
        else
            PWT:Print("Saved position: none")
        end
        if posX then
            PWT:Print(string.format("Current position: x=%.1f y=%.1f instance=%s", posX, posY or 0, tostring(instanceID or 0)))
        else
            PWT:Print("Current position: unavailable")
        end

    elseif cmd == "rdebug" then
        if PWT.Radiance then
            PWT.Radiance:SetDebugCasts(not PWT.Radiance.debugCasts)
            PWT:Print("Radiance cast debug: " ..
                (PWT.Radiance.debugCasts and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        end

    elseif cmd == "casthistory" then
        if PWT.VoidShieldDeck then PWT.VoidShieldDeck:PrintHistory() end

    elseif cmd == "forceunknown" then
        if PWT.VoidShieldDeck then
            PWT.VoidShieldDeck:EnterUnknownState("manual")
        end

    elseif cmd == "forceknown" then
        if PWT.VoidShieldDeck then
            PWT:Print("|cffff4444WARNING:|r forceknown forces a known state with arbitrary values. For debug only — this state is likely incorrect.")
            PWT.VoidShieldDeck:ResetDeck("manual forceknown", true)
            PWT.VoidShieldDeck:RefreshWidget()
        end

    elseif cmd == "mplusguard" then
        if PWT.VoidShieldDeck then
            PWT:Print("mPlusEventGuard = " .. tostring(PWT.VoidShieldDeck.mPlusEventGuard))
        end

    elseif cmd == "vsguide" or cmd == "voidshield" or cmd == "voidshieldguide" then
        if PWT.UI and PWT.UI.ShowVoidShieldGuide then
            PWT.UI:ShowVoidShieldGuide()
        else
            PWT:Print("Void Shield guide is not available yet. Open options once and try again.")
        end

    elseif cmd == "help" then
        PWT:Print("=== Power Word: Toolbox Commands ===")
        PWT:Print("|cff00ccff/pwtb vsguide|r — open the Void Shield deck guide")
        PWT:Print("|cff00ccff/pwtb debug|r — toggle debug mode")
        PWT:Print("|cff00ccff/pwtb reset|r — recentre options window")
        if PWT.db.debug then
            PWT:Print("|cff00ccff/pwtb status|r — print full addon state")
            PWT:Print("|cff00ccff/pwtb spellcheck|r — check PI cooldown state")
            PWT:Print("|cff00ccff/pwtb coords|r — print saved and current player coordinates")
            PWT:Print("|cff00ccff/pwtb seqreset|r — reset PI sequence to position 1")
            PWT:Print("|cff00ccff/pwtb casthistory|r — print Void Shield cast history")
            PWT:Print("|cff00ccff/pwtb rdebug|r — toggle Radiance cast event debug logging")
            PWT:Print("|cff00ccff/pwtb mplusguard|r — print the M+ event guard state")
            PWT:Print("|cff00ccff/pwtb forceunknown|r — force Void Shield deck into unknown state")
            PWT:Print("|cff00ccff/pwtb forceknown|r — force Void Shield deck into known state (values will be incorrect)")
        end

    else
        if PWT.UI then PWT.UI:Toggle() end
    end
end
