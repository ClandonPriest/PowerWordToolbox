-- ============================================================
--  Power Word: Toolbox  |  Modules/PI.lua
--  Power Infusion tracking: glow, sound, whisper handling,
--  priority list and sequence modes.
-- ============================================================

local _, PWT = ...

PWT.PI = {}
local PI = PWT.PI

-- ============================================================
--  Constants
-- ============================================================

local PI_SPELL_ID        = 10060
local PI_COOLDOWN_SECS   = 120
local GLOW_DURATION      = 10

local PI_SOUNDS = {
    { label = "Raid Warning",       id = SOUNDKIT.RAID_WARNING },
    { label = "Ready Check",        id = SOUNDKIT.READY_CHECK },
    { label = "PvP Flag Taken",     id = SOUNDKIT.PVP_THROUGH_QUEUE_BUTTON_CLICK },
    { label = "Quest Complete",     id = SOUNDKIT.IG_QUEST_LIST_COMPLETE },
    { label = "Alarm Clock",        id = SOUNDKIT.ALARM_CLOCK_WARNING_3 },
    { label = "Ping",               id = SOUNDKIT.UI_SPECIALTY_BUTTON_CLICK_SPECIAL },
    { label = "Battleground Start", id = SOUNDKIT.PVP_ALLIANCE_BATTLEGROUND },
    { label = "Loot Window Open",   id = SOUNDKIT.IG_BACKPACK_OPEN },
}
PI.PI_SOUNDS = PI_SOUNDS  -- expose for Options

-- ============================================================
--  State
-- ============================================================

local activeGlows    = {}
local activeRequests = {}
local soundList      = {}
local piLastCastTime = 0

PI.sequenceIndex  = 1
PI.sequenceFired  = false
PI.soundList      = soundList  -- shared reference for Options

-- ============================================================
--  Sound List
-- ============================================================

function PI:BuildSoundList()
    wipe(soundList)
    for _, s in ipairs(PI_SOUNDS) do
        soundList[#soundList + 1] = { label = s.label, sType = "preset", id = s.id }
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local lsmSounds = LSM:List("sound")
        if lsmSounds then
            table.sort(lsmSounds)
            for _, name in ipairs(lsmSounds) do
                local path = LSM:Fetch("sound", name)
                local dupe = false
                for _, existing in ipairs(soundList) do
                    if existing.label == name then dupe = true; break end
                end
                if not dupe and path then
                    soundList[#soundList + 1] = { label = name, sType = "lsm", path = path }
                end
            end
        end
    end
end

function PI:PlayCurrentSound()
    self:BuildSoundList()
    local idx   = PWT.db.pi.soundIndex or 5
    local entry = soundList[idx]
    local vol   = PWT.db.pi.soundVolume or 1.0
    local chan  = PWT.db.pi.soundChannel or "SFX"
    local prev  = GetCVar("Sound_SFXVolume")
    SetCVar("Sound_SFXVolume", tostring(vol))
    if entry and entry.sType == "lsm" then
        PWT:Debug("Playing LSM sound: " .. entry.label, "pi")
        PlaySoundFile(entry.path, chan)
    else
        local preset = PI_SOUNDS[idx] or PI_SOUNDS[5]
        PWT:Debug("Playing preset sound: " .. preset.label, "pi")
        PlaySound(preset.id, chan, false)
    end
    C_Timer.After(0.5, function() SetCVar("Sound_SFXVolume", prev) end)
end

-- ============================================================
--  Glow
-- ============================================================

function PI:ApplyGlow(frame, playerName)
    if not frame then return end
    if activeGlows[playerName] then
        PWT:Debug("Glow already active for " .. playerName .. ", ignoring repeat.", "pi")
        return
    end

    local cfg   = PWT.db.pi
    local r     = cfg.glowR or 1.0
    local g     = cfg.glowG or 0.85
    local b     = cfg.glowB or 0.0
    local op    = cfg.glowOpacity or 0.55
    local pulse = math.max(0.1, cfg.glowPulse or 0.6)
    local style = cfg.glowStyle or "overlay"

    -- Sound
    if cfg.soundEnabled ~= false then
        self:BuildSoundList()
        local idx     = cfg.soundIndex or 5
        local entry   = soundList[idx]
        local vol     = cfg.soundVolume or 1.0
        local chan    = cfg.soundChannel or "SFX"
        local prev    = GetCVar("Sound_SFXVolume")
        SetCVar("Sound_SFXVolume", tostring(vol))
        if entry and entry.sType == "lsm" then
            PWT:Debug("Playing LSM sound: " .. entry.label, "pi")
            PlaySoundFile(entry.path, chan)
        else
            local preset = PI_SOUNDS[idx] or PI_SOUNDS[5]
            PWT:Debug("Playing preset sound: " .. preset.label, "pi")
            PlaySound(preset.id, chan, false)
        end
        C_Timer.After(0.5, function() SetCVar("Sound_SFXVolume", prev) end)
    end

    -- Glow visual
    if cfg.glowEnabled ~= false then
        if style == "overlay" then
            -- Overlay: simple full-frame colour wash, parented to frame
            local glow = CreateFrame("Frame", nil, frame)
            glow:SetAllPoints(frame)
            glow:SetFrameLevel(frame:GetFrameLevel() + 5)
            local tex = glow:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(glow)
            tex:SetColorTexture(r, g, b, op)
            local ag = glow:CreateAnimationGroup()
            ag:SetLooping("BOUNCE")
            local a = ag:CreateAnimation("Alpha")
            a:SetFromAlpha(0.15)
            a:SetToAlpha(1.0)
            a:SetDuration(pulse)
            ag:Play()
            glow:Show()
            activeGlows[playerName]    = glow
            activeRequests[playerName] = true

        elseif style == "border" then
            -- Outer glow: concentric border rings expanding outward from the frame.
            -- Each ring is 4 strip textures (top/bottom/left/right) with ADD blend.
            -- Parented to UIParent to avoid parent-frame clipping.
            local glow = CreateFrame("Frame", nil, UIParent)
            glow:SetFrameStrata("HIGH")
            glow:SetFrameLevel(frame:GetFrameLevel() + 10)

            local thick  = cfg.borderThickness or 3
            local spread = math.max(8, thick * 5)
            -- rings: distance from frame edge -> opacity
            local ringDefs = {
                { dist=0,             alpha=1.00 },
                { dist=spread*0.25,   alpha=0.60 },
                { dist=spread*0.50,   alpha=0.30 },
                { dist=spread*0.75,   alpha=0.14 },
                { dist=spread*1.00,   alpha=0.05 },
            }
            local lineW = math.max(3, thick)

            -- Build strip textures for all rings upfront
            local strips = {}  -- { tex, ringIdx, side }
            for i, rd in ipairs(ringDefs) do
                for _, side in ipairs({"top","bot","left","right"}) do
                    local t = glow:CreateTexture(nil, "OVERLAY")
                    t:SetColorTexture(r, g, b, op * rd.alpha)
                    t:SetBlendMode("ADD")
                    strips[#strips+1] = { tex=t, ringIdx=i, side=side }
                end
            end

            local elapsed = 0
            glow:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                -- Pulse the whole glow frame
                local alpha = 0.35 + 0.65 * math.abs(math.sin(elapsed * math.pi / pulse))
                self:SetAlpha(alpha)
            end)

            -- Position all strips relative to frame directly — no coordinate conversion
            for _, s in ipairs(strips) do
                local d = ringDefs[s.ringIdx].dist
                local t = s.tex
                if s.side == "top" then
                    t:SetPoint("BOTTOMLEFT",  frame, "TOPLEFT",  -d, d)
                    t:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT",  d, d)
                    t:SetHeight(lineW)
                elseif s.side == "bot" then
                    t:SetPoint("TOPLEFT",     frame, "BOTTOMLEFT",  -d, -d)
                    t:SetPoint("TOPRIGHT",    frame, "BOTTOMRIGHT",  d, -d)
                    t:SetHeight(lineW)
                elseif s.side == "left" then
                    t:SetPoint("TOPRIGHT",    frame, "TOPLEFT",    -d,  d)
                    t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -d, -d)
                    t:SetWidth(lineW)
                elseif s.side == "right" then
                    t:SetPoint("TOPLEFT",    frame, "TOPRIGHT",    d,  d)
                    t:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", d, -d)
                    t:SetWidth(lineW)
                end
            end

            glow:Show()
            activeGlows[playerName]    = glow
            activeRequests[playerName] = true
        end  -- if style
    end  -- if glowEnabled

    self:ShowOverlay(playerName)
    PWT:Debug("Alert triggered for: " .. playerName, "pi")

    C_Timer.After(GLOW_DURATION, function()
        if activeGlows[playerName] then
            activeGlows[playerName]:SetScript("OnUpdate", nil)
            activeGlows[playerName]:Hide()
            activeGlows[playerName] = nil
        end
        activeRequests[playerName] = nil
        self:HideOverlay()
        PWT:Debug("Alert expired for: " .. playerName, "pi")
    end)
end


function PI:ClearGlow(playerName)
    if activeGlows[playerName] then
        activeGlows[playerName]:SetScript("OnUpdate", nil)
        activeGlows[playerName]:Hide()
        activeGlows[playerName]    = nil
        activeRequests[playerName] = nil
        self:HideOverlay()
        PWT:Debug("Cleared glow for: " .. playerName, "pi")
    end
end

function PI:ClearAllGlows()
    local count = 0
    for name, glow in pairs(activeGlows) do
        glow:SetScript("OnUpdate", nil)
        glow:Hide()
        activeGlows[name]    = nil
        activeRequests[name] = nil
        count = count + 1
    end
    if count > 0 then
        self:HideOverlay()
        PWT:Debug("ClearAllGlows: cleared " .. count .. " active glow(s).", "pi")
    end
end

-- ============================================================
--  Cooldown Tracking
-- ============================================================

function PI:IsReady()
    if piLastCastTime == 0 then return true end
    local elapsed   = GetTime() - piLastCastTime
    local remaining = PI_COOLDOWN_SECS - elapsed
    if remaining > 0 then
        PWT:Debug("PI cooldown remaining: " .. string.format("%.1f", remaining) .. "s", "pi")
        return false
    end
    return true
end

function PI:PrintCooldownState()
    PWT:Print("PI self-tracked cooldown state:")
    if piLastCastTime == 0 then
        PWT:Print("PI has not been cast this session — treating as |cff00ff00READY|r")
    else
        local elapsed   = GetTime() - piLastCastTime
        local remaining = PI_COOLDOWN_SECS - elapsed
        if remaining > 0 then
            PWT:Print("PI on cooldown: |cffff4444" .. string.format("%.1f", remaining) .. "s|r remaining")
        else
            PWT:Print("PI is |cff00ff00READY|r (cast " .. string.format("%.0f", elapsed) .. "s ago)")
        end
    end
end

function PI:PrintStatus()
    local mode = PWT.db.piMode or "priority"
    PWT:Print("PI enabled="  .. tostring(PWT.db.piEnabled) ..
        "  mode="    .. mode ..
        "  piReady=" .. tostring(self:IsReady()))
    PWT:Print("PI priority list: " .. #PWT.db.piList .. " entries")
    PWT:Print("PI sequence list: " .. #PWT.db.piSequenceList ..
        " entries  seqIndex=" .. self.sequenceIndex ..
        "  fired="   .. tostring(self.sequenceFired))
    PWT:Print("Glow: style="   .. tostring(PWT.db.pi.glowStyle) ..
        "  enabled="  .. tostring(PWT.db.pi.glowEnabled) ..
        "  sound="    .. tostring(PWT.db.pi.soundEnabled))
end

-- ============================================================
--  Sequence
-- ============================================================

function PI:ResetSequence()
    self.sequenceIndex = 1
    self.sequenceFired = false
    PWT:Debug("PI sequence reset to position 1.", "pi")
    if _G["PowerWordToolboxOptions"] and _G["PowerWordToolboxOptions"]:IsShown() then
        if PWT.UI then PWT.UI:RefreshPI() end
    end
end

-- ============================================================
--  Player / Group Lookup
-- ============================================================

local function StripRealm(n)
    if not n then return nil end
    n = n:match("^([^%-]+)") or n
    n = n:match("^(.-)%s*%(%*%)%s*$") or n
    return n:lower()
end

local function IsPlayerInGroup(name)
    local lowerName = name:lower()
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if StripRealm(GetUnitName(unit, false)) == lowerName then return true, unit end
    end
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if StripRealm(GetUnitName(unit, false)) == lowerName then return true, unit end
    end
    if StripRealm(GetUnitName("player", false)) == lowerName then return true, "player" end
    return false, nil
end

-- ============================================================
--  Whisper Handler
-- ============================================================

function PI:OnWhisper()
    if not InCombatLockdown() then
        PWT:Debug("Whisper ignored (not in combat).", "pi")
        return
    end
    if not PWT.db.piEnabled then
        PWT:Debug("Whisper ignored (PI feature disabled).", "pi")
        return
    end
    if not self:IsReady() then
        PWT:Debug("Whisper ignored (PI on cooldown).", "pi")
        return
    end

    local mode = PWT.db.piMode or "priority"

    if mode == "sequence" then
        if self.sequenceFired then
            PWT:Debug("Sequence: already triggered for this cast slot, ignoring.", "pi")
            return
        end
        local seq = PWT.db.piSequenceList
        if not seq or #seq == 0 then
            PWT:Debug("Sequence list is empty.", "pi")
            return
        end
        local idx = self.sequenceIndex
        if idx > #seq then
            if PWT.db.piSequenceStickLast then
                -- Stick mode: repeat the last entry indefinitely.
                idx = #seq
                PWT:Debug("Sequence: sticking to last entry (" .. seq[idx] .. ").", "pi")
            else
                -- Loop mode: wrap back to position 1.
                idx = 1
                self.sequenceIndex = 1
                PWT:Debug("Sequence: looping back to position 1.", "pi")
            end
        end
        local name = seq[idx]
        local inGroup, unitToken = IsPlayerInGroup(name)
        if inGroup then
            local raidFrame = PWT.RaidFrames:Find(unitToken)
            if raidFrame then
                self:ApplyGlow(raidFrame, name)
                PWT:Print("|cffFFD700PI Seq [" .. idx .. "/" .. #seq .. "]: " .. name .. "|r")
            else
                PWT:Debug("Sequence: in group but no raid frame for: " .. name, "pi")
            end
        else
            PWT:Debug("Sequence target " .. name .. " not in group, skipping.", "pi")
        end
        self.sequenceIndex = idx + 1
        self.sequenceFired = true
        if _G["PowerWordToolboxOptions"] and _G["PowerWordToolboxOptions"]:IsShown() then
            if PWT.UI then PWT.UI:RefreshPI() end
        end

    else
        for _, name in ipairs(PWT.db.piList) do
            local inGroup, unitToken = IsPlayerInGroup(name)
            if inGroup then
                local raidFrame = PWT.RaidFrames:Find(unitToken)
                if raidFrame then
                    self:ApplyGlow(raidFrame, name)
                    PWT:Print("|cffFFD700PI: " .. name .. "|r")
                else
                    PWT:Debug("In group but no raid frame for: " .. name, "pi")
                end
                return
            end
        end
        PWT:Debug("Whisper received but no priority list members found in group. List size: " .. #PWT.db.piList, "pi")
    end
end

-- ============================================================
--  Event Handlers
-- ============================================================

function PI:OnLogin()
    self:BuildSoundList()
end

function PI:OnSpellCast(unit, spellID)
    if unit == "player" and spellID == PI_SPELL_ID then
        piLastCastTime     = GetTime()
        self.sequenceFired = false
        PWT:Debug("PI cast detected, cooldown started.", "pi")
        self:ClearAllGlows()
    end
end

function PI:OnLeaveCombat()
    self:ClearAllGlows()
    PWT:Debug("Left combat, cleared all glows.", "pi")
end

-- ============================================================
--  Name Overlay Widget
-- ============================================================

local overlayWidget = nil
local overlayMovable = false

function PI:CreateOverlayWidget()
    if overlayWidget then return end

    local f = CreateFrame("Frame", "PWT_PIOverlay", UIParent)
    f:SetSize(280, 60)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        if PWT.db and PWT.db.pi then
            PWT.db.pi.overlayPosX = x - UIParent:GetWidth()  / 2
            PWT.db.pi.overlayPosY = y - UIParent:GetHeight() / 2
        end
    end)

    -- Drag-mode background: only visible when the frame is unlocked for moving.
    -- Fully transparent during normal use so nothing but icon + text is visible.
    local bgTex = f:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(f)
    bgTex:SetColorTexture(0.08, 0.04, 0.18, 0)  -- alpha=0 by default
    f.bgTex = bgTex

    -- PI spell icon
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local spellInfo = C_Spell.GetSpellInfo(PI_SPELL_ID)
    icon:SetTexture(spellInfo and spellInfo.iconID or 135926)
    f.icon = icon

    -- "Give [name] PI" label
    local nameText = f:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("LEFT",  icon, "RIGHT", 8, 0)
    nameText:SetPoint("RIGHT", f,    "RIGHT", 0, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 0.85, 0.1, 1)  -- warm gold, readable without a bg
    f.nameText = nameText

    -- Bounce animation: two explicit translations (up then down) with IN_OUT smoothing
    -- on each leg so velocity reaches zero at both the top and bottom — no jump at reversal.
    local bounceAG = f:CreateAnimationGroup()
    bounceAG:SetLooping("REPEAT")
    local bounceUp = bounceAG:CreateAnimation("Translation")
    bounceUp:SetOffset(0, 10)
    bounceUp:SetDuration(0.4)
    bounceUp:SetOrder(1)
    bounceUp:SetSmoothing("IN_OUT")
    local bounceDown = bounceAG:CreateAnimation("Translation")
    bounceDown:SetOffset(0, -10)
    bounceDown:SetDuration(0.4)
    bounceDown:SetOrder(2)
    bounceDown:SetSmoothing("IN_OUT")
    f.bounceAG = bounceAG

    -- Restore saved position
    f:ClearAllPoints()
    local px = PWT.db and PWT.db.pi and PWT.db.pi.overlayPosX
    local py = PWT.db and PWT.db.pi and PWT.db.pi.overlayPosY
    if px and py then
        f:SetPoint("CENTER", UIParent, "CENTER", px, py)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    f:Hide()
    overlayWidget = f
    self:UpdateOverlayFont()
end

function PI:UpdateOverlayFont()
    if not overlayWidget then return end
    local size = (PWT.db and PWT.db.pi and PWT.db.pi.overlayFontSize) or 24
    local font = (PWT.db and PWT.db.font) or "Fonts\\FRIZQT__.TTF"
    if not pcall(function()
        overlayWidget.nameText:SetFont(font, size, "OUTLINE")
    end) then
        overlayWidget.nameText:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
    local iconSize = math.max(32, size + 8)
    overlayWidget.icon:SetSize(iconSize, iconSize)
    overlayWidget:SetHeight(math.max(52, iconSize + 16))
end

function PI:ShowOverlay(name)
    if not (PWT.db and PWT.db.pi and PWT.db.pi.overlayEnabled) then return end
    if not overlayWidget then self:CreateOverlayWidget() end
    overlayWidget.nameText:SetText("Give " .. name .. " PI")
    overlayWidget:Show()
    overlayWidget.bounceAG:Play()
end

function PI:HideOverlay()
    if overlayWidget and not overlayMovable then
        overlayWidget.bounceAG:Stop()
        overlayWidget:Hide()
    end
end

function PI:SetOverlayMovable(canMove)
    if not overlayWidget then return end
    overlayMovable = canMove
    overlayWidget:EnableMouse(canMove)
    -- Show a faint tint so the frame boundary is visible while repositioning
    overlayWidget.bgTex:SetColorTexture(0.08, 0.04, 0.18, canMove and 0.75 or 0)
end

function PI:ForceHideOverlay()
    overlayMovable = false
    if overlayWidget then
        overlayWidget.bounceAG:Stop()
        overlayWidget:Hide()
    end
end

function PI:OnEncounterStart()
    -- Sequence mode: reset both the cooldown tracker and sequence position
    -- so the sequence starts fresh from position 1 on each pull.
    -- Priority mode: only reset the sequence state (harmless), but leave the
    -- cooldown tracker intact so the CD gate still works between pulls.
    if PWT.db and PWT.db.piMode == "sequence" then
        piLastCastTime = 0
        PWT:Debug("Encounter started (sequence mode): cooldown and sequence reset.", "pi")
    else
        PWT:Debug("Encounter started (priority mode): sequence state reset, cooldown preserved.", "pi")
    end
    self:ResetSequence()
end