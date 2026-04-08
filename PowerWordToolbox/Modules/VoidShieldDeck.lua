-- ============================================================
--  Power Word: Toolbox  |  Modules/VoidShieldDeck.lua
--  Void Shield deck tracker for Discipline Priests.
--
--  Deck mechanic: 3 cards (2 no-proc + 1 proc).
--  Each Penance cast draws one card.
--    Chance = 1/cardsRemaining  while proc card is still in deck.
--    Chance = 0%                after the proc card is drawn.
--  Deck resets when empty, on raid encounter start, or M+ start.
--
--  Proc detection: monitor the action bar slot that holds
--  Power Word: Shield.  When its texture changes to the Void
--  Shield icon the proc fired; the slot reverts when consumed.
-- ============================================================

local _, PWT = ...

PWT.VoidShieldDeck = {}
local VSD = PWT.VoidShieldDeck

-- ── Constants ────────────────────────────────────────────────
local PENANCE_SPELL_ID  = 47540
local PWS_SPELL_ID      = 17
local PWS_PROC_SPELL_ID = 1253593
local BASE_SLOT_TEXTURE = 135940    -- Power Word: Shield icon
local PROC_TEXTURE_ID   = 7514191   -- Void Shield icon (proc active)
local MAX_CARDS         = 3
local OUTCOME_TIMEOUT   = 0.25      -- seconds to wait before assuming no-proc
local PROC_ALERT_TIMEOUT = 6        -- seconds before proc icon alert auto-dismisses

local VSD_SOUNDS = {
    { label = "Raid Warning",       id = SOUNDKIT.RAID_WARNING },
    { label = "Ready Check",        id = SOUNDKIT.READY_CHECK },
    { label = "PvP Flag Taken",     id = SOUNDKIT.PVP_THROUGH_QUEUE_BUTTON_CLICK },
    { label = "Quest Complete",     id = SOUNDKIT.IG_QUEST_LIST_COMPLETE },
    { label = "Alarm Clock",        id = SOUNDKIT.ALARM_CLOCK_WARNING_3 },
    { label = "Ping",               id = SOUNDKIT.UI_SPECIALTY_BUTTON_CLICK_SPECIAL },
    { label = "Battleground Start", id = SOUNDKIT.PVP_ALLIANCE_BATTLEGROUND },
    { label = "Loot Window Open",   id = SOUNDKIT.IG_BACKPACK_OPEN },
}

-- Action bar button frame prefixes for the fallback texture scan.
local ACTION_BAR_PREFIXES = {
    "ActionButton",
    "MultiActionBar1Button",
    "MultiActionBar2Button",
    "MultiActionBar3Button",
    "MultiActionBar4Button",
}

-- ── Deck State ───────────────────────────────────────────────
VSD.cardsRemaining  = MAX_CARDS
VSD.procAvailable   = true   -- proc card is still in the deck
VSD.awaitingOutcome = false  -- true while waiting to detect this cast's result
VSD.pendingCastID   = 0
VSD.widgetVisible   = false  -- true while the module is actively displayed

-- ── Widget handles (all created lazily in BuildWidget) ───────
-- Three independent draggable frames:
--   chanceWidget – "Chance: X%"
--   deckWidget   – "Deck: X / 3"
--   cardsWidget  – colored card slots
local chanceWidget = nil
local deckWidget   = nil
local cardsWidget  = nil
local chanceBg     = nil
local deckBg       = nil
local cardsBg      = nil
local chanceLabel  = nil
local deckLabel    = nil
local cardTextures = {}

local pendingTimer = nil
local pwsSlot      = nil   -- action-bar slot that holds PWS / Void Shield

-- ── Sound list (built lazily, shared with Options) ────────────
local soundList = {}
VSD.soundList   = soundList

-- ── Proc alert widget (created lazily in BuildProcAlert) ──────
local procAlertWidget  = nil
local procAlertBg      = nil
local procAlertTimer   = nil
VSD.procAlertActive    = false
VSD.procAlertPreview   = false  -- true while showing the positioning preview

-- ─────────────────────────────────────────────────────────────
--  Internal helpers
-- ─────────────────────────────────────────────────────────────

local function ClampFontSize(size)
    return math.max(10, math.min(40, size or 18))
end

local function FormatChance(value)
    return string.format("%d%%", math.floor((value or 0) + 0.5))
end

-- Scan visible action button frames for the PWS or Void Shield texture.
-- Used as a fallback when GetActionInfo fails to locate the slot.
local function ScanButtonFrames()
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn and btn.icon then
                local tex = btn.icon:GetTexture()
                if tex == PROC_TEXTURE_ID or tex == BASE_SLOT_TEXTURE then
                    return tex
                end
            end
        end
    end
    return nil
end

local function FindPWSSlot()
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and (id == PWS_SPELL_ID or id == PWS_PROC_SPELL_ID) then
            PWT:Debug("VSD: PWS found via GetActionInfo – slot=" .. slot .. " spellID=" .. id, "voidshield")
            return slot
        end
    end
    local frameTex = ScanButtonFrames()
    if frameTex then
        PWT:Debug("VSD: GetActionInfo found nothing, but ScanButtonFrames found texture=" .. tostring(frameTex) .. ". Will use frame scan for proc detection.", "voidshield")
    else
        PWT:Debug("VSD: PWS not found by GetActionInfo OR ScanButtonFrames – is PWS on an action bar?", "voidshield")
    end
    return nil
end

local function IsProcTextureActive()
    local tex
    if pwsSlot then
        tex = GetActionTexture(pwsSlot)
        if not tex then
            PWT:Debug("VSD: GetActionTexture(slot=" .. pwsSlot .. ") returned nil – falling back to ScanButtonFrames.", "voidshield")
            tex = ScanButtonFrames()
        end
    else
        PWT:Debug("VSD: pwsSlot nil – using ScanButtonFrames.", "voidshield")
        tex = ScanButtonFrames()
    end

    if not tex then
        PWT:Debug("VSD: No PWS/VoidShield texture found by any method.", "voidshield")
        return false
    end

    local isProc = (tex == PROC_TEXTURE_ID)
    PWT:Debug("VSD: texture=" .. tostring(tex)
        .. "  base=" .. BASE_SLOT_TEXTURE
        .. "  proc=" .. PROC_TEXTURE_ID
        .. "  isProc=" .. tostring(isProc), "voidshield")
    return isProc
end

-- ─────────────────────────────────────────────────────────────
--  Deck logic
-- ─────────────────────────────────────────────────────────────

function VSD:GetChance()
    if not self.procAvailable then return 0 end
    return self.cardsRemaining > 0 and (100 / self.cardsRemaining) or 0
end

function VSD:ResetDeck(reason)
    self.cardsRemaining  = MAX_CARDS
    self.procAvailable   = true
    self.awaitingOutcome = false
    self.pendingCastID   = 0
    if pendingTimer then
        pendingTimer:Cancel()
        pendingTimer = nil
    end
    self:HideProcAlert()
    self:UpdateWidget()
    PWT:Debug("VSD deck reset" .. (reason and (" – " .. reason) or "") .. ".", "voidshield")
end

function VSD:ApplyCastResult(didProc)
    self.awaitingOutcome = false
    if pendingTimer then
        pendingTimer:Cancel()
        pendingTimer = nil
    end

    if didProc then
        self.procAvailable = false
        if PWT.db and PWT.db.voidShieldDeck then
            local cfg = PWT.db.voidShieldDeck
            if cfg.procAlertEnabled  then self:ShowProcAlert()  end
            if cfg.procSoundEnabled  then self:PlayProcSound()  end
        end
    end
    self.cardsRemaining = math.max(0, self.cardsRemaining - 1)

    PWT:Debug("VSD: ApplyCastResult didProc=" .. tostring(didProc)
        .. "  cardsRemaining=" .. self.cardsRemaining
        .. "  procAvailable="  .. tostring(self.procAvailable), "voidshield")

    if self.cardsRemaining == 0 then
        self:ResetDeck("deck empty")
    else
        self:UpdateWidget()
    end
end

function VSD:CheckForProc()
    if not self.awaitingOutcome then return end
    PWT:Debug("VSD: CheckForProc called (awaitingOutcome=true)", "voidshield")
    if IsProcTextureActive() then
        PWT:Debug("VSD: Proc texture confirmed – applying proc result.", "voidshield")
        self:ApplyCastResult(true)
    else
        PWT:Debug("VSD: No proc texture – cast did not proc.", "voidshield")
    end
end

function VSD:OnPenanceCast()
    PWT:Debug("VSD: Penance cast detected. procAvailable=" .. tostring(self.procAvailable)
        .. "  cardsRemaining=" .. self.cardsRemaining, "voidshield")

    if not self.procAvailable then
        self.cardsRemaining = math.max(0, self.cardsRemaining - 1)
        PWT:Debug("VSD: Proc not available – consumed no-proc card. cardsRemaining=" .. self.cardsRemaining, "voidshield")
        if self.cardsRemaining == 0 then
            self:ResetDeck("deck empty")
        else
            self:UpdateWidget()
        end
        return
    end

    if not pwsSlot then
        PWT:Debug("VSD: pwsSlot not cached, searching now.", "voidshield")
        pwsSlot = FindPWSSlot()
    end

    self.awaitingOutcome = true
    self.pendingCastID   = self.pendingCastID + 1
    local castID         = self.pendingCastID
    PWT:Debug("VSD: Awaiting outcome for castID=" .. castID .. " (timeout=" .. OUTCOME_TIMEOUT .. "s)", "voidshield")

    if pendingTimer then pendingTimer:Cancel() end
    pendingTimer = C_Timer.NewTimer(OUTCOME_TIMEOUT, function()
        if self.awaitingOutcome and self.pendingCastID == castID then
            PWT:Debug("VSD: Timeout fired for castID=" .. castID .. " – running final proc check.", "voidshield")
            self:CheckForProc()
            if self.awaitingOutcome then
                PWT:Debug("VSD: Still unresolved after timeout – applying no-proc.", "voidshield")
                self:ApplyCastResult(false)
            end
        else
            PWT:Debug("VSD: Timeout fired but stale (castID=" .. castID .. " current=" .. self.pendingCastID .. ") – ignoring.", "voidshield")
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
--  Widget
-- ─────────────────────────────────────────────────────────────

local CARD_COLORS = {
    {0.80, 0.15, 0.15, 1.0},  -- slot 1: red  (no-proc)
    {0.80, 0.15, 0.15, 1.0},  -- slot 2: red  (no-proc)
    {0.15, 0.75, 0.25, 1.0},  -- slot 3: green (proc)
}

-- Creates a minimal draggable frame that saves its position to the given db keys.
-- Starts locked (movable=false, mouse=false, bg transparent).
local function MakeSubWidget(frameName, posXKey, posYKey)
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(false)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not PWT.db or not PWT.db.voidShieldDeck then return end
        local x, y = self:GetCenter()
        PWT.db.voidShieldDeck[posXKey] = x - UIParent:GetWidth()  / 2
        PWT.db.voidShieldDeck[posYKey] = y - UIParent:GetHeight() / 2
    end)
    f:SetScript("OnEnter", function(self)
        if not self:IsMovable() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffcc99ffVoid Shield Tracker|r")
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0)   -- hidden until unlocked

    return f, bg
end

-- Builds all three frames on first call; no-op afterwards.
-- Must only be called after PLAYER_LOGIN (PWT.db must exist).
function VSD:BuildWidget()
    if chanceWidget then return end

    chanceWidget, chanceBg = MakeSubWidget("PWT_VSDChanceWidget", "chancePosX", "chancePosY")
    deckWidget,   deckBg   = MakeSubWidget("PWT_VSDDeckWidget",   "deckPosX",   "deckPosY")
    cardsWidget,  cardsBg  = MakeSubWidget("PWT_VSDCardsWidget",  "cardsPosX",  "cardsPosY")

    chanceLabel = chanceWidget:CreateFontString(nil, "OVERLAY")
    chanceLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    chanceLabel:SetPoint("CENTER", chanceWidget, "CENTER", 0, 0)
    chanceLabel:SetTextColor(1.0, 0.85, 0.45)

    deckLabel = deckWidget:CreateFontString(nil, "OVERLAY")
    deckLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    deckLabel:SetPoint("CENTER", deckWidget, "CENTER", 0, 0)
    deckLabel:SetTextColor(1.0, 1.0, 1.0)

    cardsWidget:SetSize(MAX_CARDS * 34 - 6, 22)
    for i = 1, MAX_CARDS do
        local card = cardsWidget:CreateTexture(nil, "OVERLAY")
        card:SetSize(28, 18)
        local col = CARD_COLORS[i]
        card:SetColorTexture(col[1], col[2], col[3], col[4])
        card:SetPoint("LEFT", cardsWidget, "LEFT", (i - 1) * 34, 2)
        cardTextures[i] = card
    end

    chanceWidget:Hide()
    deckWidget:Hide()
    cardsWidget:Hide()
end

function VSD:UpdateWidget()
    if not chanceWidget then return end
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck

    local fontPath      = (PWT.db.font and PWT.db.font ~= "") and PWT.db.font or "Fonts\\FRIZQT__.TTF"
    local chanceFontSz  = ClampFontSize(cfg.chanceFontSize)
    local deckFontSz    = ClampFontSize(cfg.deckFontSize)
    local cardsSize     = math.max(8, math.min(48, cfg.cardsSize or 18))
    local cardW         = math.floor(cardsSize * 1.56 + 0.5)
    local cardSpacing   = cardW + 6   -- card width + 6px gap between cards

    -- Reposition each frame from saved db values.
    local function positionWidget(f, posXKey, posYKey, defaultX, defaultY)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", cfg[posXKey] or defaultX, cfg[posYKey] or defaultY)
    end
    positionWidget(chanceWidget, "chancePosX", "chancePosY", 0, 160)
    positionWidget(deckWidget,   "deckPosX",   "deckPosY",   0, 130)
    positionWidget(cardsWidget,  "cardsPosX",  "cardsPosY",  0, 105)

    -- Chance
    chanceLabel:SetFont(fontPath, chanceFontSz, "OUTLINE")
    local chanceVal = FormatChance(self:GetChance())
    chanceLabel:SetText(cfg.showChanceLabel ~= false and ("Chance: " .. chanceVal) or chanceVal)
    chanceWidget:SetSize(math.max(60, chanceLabel:GetStringWidth() + 10), chanceFontSz + 10)

    -- Deck count
    deckLabel:SetFont(fontPath, deckFontSz, "OUTLINE")
    local cards = self.cardsRemaining or MAX_CARDS
    local deckVal = cards .. " / " .. MAX_CARDS
    deckLabel:SetText(cfg.showDeckLabel ~= false and ("Deck: " .. deckVal) or deckVal)
    deckWidget:SetSize(math.max(60, deckLabel:GetStringWidth() + 10), deckFontSz + 10)

    -- Card visuals: resize and reposition all cards from cfg each update.
    -- ClearAllPoints is required so switching between horizontal/vertical
    -- orientations doesn't accumulate conflicting anchor points.
    if cfg.cardsRotated then
        -- Vertical stack: cards are taller than wide, stacked top-to-bottom.
        local vertSpacing = cardW + 6
        cardsWidget:SetSize(cardsSize + 4, MAX_CARDS * vertSpacing - 6)
        for i = 1, MAX_CARDS do
            if cardTextures[i] then
                local pos = MAX_CARDS - i  -- reversed: card 3 (green) → top, card 1 (red) → bottom
                cardTextures[i]:SetSize(cardsSize, cardW)
                cardTextures[i]:ClearAllPoints()
                cardTextures[i]:SetPoint("TOPLEFT", cardsWidget, "TOPLEFT", 2, -pos * vertSpacing)
            end
        end
    else
        -- Horizontal row (default): cards are wider than tall, stacked left-to-right.
        cardsWidget:SetSize(MAX_CARDS * cardSpacing - 6, cardsSize + 4)
        for i = 1, MAX_CARDS do
            if cardTextures[i] then
                cardTextures[i]:SetSize(cardW, cardsSize)
                cardTextures[i]:ClearAllPoints()
                cardTextures[i]:SetPoint("LEFT", cardsWidget, "LEFT", (i - 1) * cardSpacing, 2)
            end
        end
    end

    -- Frame strata.
    chanceWidget:SetFrameStrata(cfg.chanceStrata or "MEDIUM")
    deckWidget:SetFrameStrata(cfg.deckStrata   or "MEDIUM")
    cardsWidget:SetFrameStrata(cfg.cardsStrata  or "MEDIUM")

    -- Per-element show/hide driven by widgetVisible + individual toggles.
    local on = self.widgetVisible
    chanceWidget:SetShown(on and cfg.showChance ~= false)
    deckWidget:SetShown(on and cfg.showDeck ~= false)
    cardsWidget:SetShown(on and cfg.showCards ~= false)

    -- Card slot visuals.
    -- Slots 1 & 2 = red no-proc cards, slot 3 = green proc card.
    local remainingRed = self.procAvailable
        and math.max(0, cards - 1)
        or  cards
    for i = 1, 2 do
        if cardTextures[i] then cardTextures[i]:SetShown(i <= remainingRed) end
    end
    if cardTextures[3] then
        cardTextures[3]:SetShown(self.procAvailable == true)
    end
end

function VSD:ShowWidget()
    self:BuildWidget()
    self.widgetVisible = true
    self:UpdateWidget()
end

function VSD:HideWidget()
    self.widgetVisible = false
    if chanceWidget then chanceWidget:Hide() end
    if deckWidget   then deckWidget:Hide()   end
    if cardsWidget  then cardsWidget:Hide()  end
    self:HideProcAlert()
end

function VSD:ApplyStrata()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck
    if chanceWidget    then chanceWidget:SetFrameStrata(cfg.chanceStrata    or "MEDIUM") end
    if deckWidget      then deckWidget:SetFrameStrata(cfg.deckStrata        or "MEDIUM") end
    if cardsWidget     then cardsWidget:SetFrameStrata(cfg.cardsStrata      or "MEDIUM") end
    if procAlertWidget then procAlertWidget:SetFrameStrata(cfg.procAlertStrata or "HIGH") end
end

function VSD:SetMovable(enabled)
    local function toggleWidget(f, bg)
        if not f then return end
        f:SetMovable(enabled)
        f:EnableMouse(enabled)
        if bg then
            if enabled then
                bg:SetColorTexture(0.15, 0.15, 0.15, 0.45)
            else
                bg:SetColorTexture(0, 0, 0, 0)
            end
        end
    end
    toggleWidget(chanceWidget, chanceBg)
    toggleWidget(deckWidget,   deckBg)
    toggleWidget(cardsWidget,  cardsBg)
end

function VSD:ResetPosition()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck
    cfg.chancePosX = nil;  cfg.chancePosY = nil
    cfg.deckPosX   = nil;  cfg.deckPosY   = nil
    cfg.cardsPosX  = nil;  cfg.cardsPosY  = nil
    if chanceWidget then chanceWidget:ClearAllPoints(); chanceWidget:SetPoint("CENTER", UIParent, "CENTER", 0, 160) end
    if deckWidget   then deckWidget:ClearAllPoints();   deckWidget:SetPoint("CENTER",   UIParent, "CENTER", 0, 130) end
    if cardsWidget  then cardsWidget:ClearAllPoints();  cardsWidget:SetPoint("CENTER",  UIParent, "CENTER", 0, 105) end
end

-- ─────────────────────────────────────────────────────────────
--  Proc Alert  (icon + sound on proc detection)
-- ─────────────────────────────────────────────────────────────

function VSD:BuildSoundList()
    wipe(soundList)
    for _, s in ipairs(VSD_SOUNDS) do
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

function VSD:PlayProcSound()
    self:BuildSoundList()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg   = PWT.db.voidShieldDeck
    local idx   = cfg.procSoundIndex or 5
    local entry = soundList[idx]
    local vol   = cfg.procSoundVolume  or 1.0
    local chan  = cfg.procSoundChannel or "SFX"
    local prev  = GetCVar("Sound_SFXVolume")
    SetCVar("Sound_SFXVolume", tostring(vol))
    if entry and entry.sType == "lsm" then
        PWT:Debug("VSD proc sound LSM: " .. entry.label, "voidshield")
        PlaySoundFile(entry.path, chan)
    else
        local preset = VSD_SOUNDS[idx] or VSD_SOUNDS[5]
        PWT:Debug("VSD proc sound preset: " .. preset.label, "voidshield")
        PlaySound(preset.id, chan, false)
    end
    C_Timer.After(0.5, function() SetCVar("Sound_SFXVolume", prev) end)
end

-- Lazily creates the proc alert frame (the icon that flashes on proc).
function VSD:BuildProcAlert()
    if procAlertWidget then return end
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck

    procAlertWidget = CreateFrame("Frame", "PWT_VSDProcAlert", UIParent)
    procAlertWidget:SetFrameStrata(cfg.procAlertStrata or "HIGH")
    procAlertWidget:SetClampedToScreen(true)
    procAlertWidget:SetMovable(false)
    procAlertWidget:EnableMouse(false)
    procAlertWidget:RegisterForDrag("LeftButton")

    procAlertWidget:SetScript("OnDragStart", function(self) self:StartMoving() end)
    procAlertWidget:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not PWT.db or not PWT.db.voidShieldDeck then return end
        local x, y = self:GetCenter()
        PWT.db.voidShieldDeck.procAlertPosX = x - UIParent:GetWidth()  / 2
        PWT.db.voidShieldDeck.procAlertPosY = y - UIParent:GetHeight() / 2
    end)
    procAlertWidget:SetScript("OnEnter", function(self)
        if not self:IsMovable() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffcc99ffVoid Shield Proc Alert|r")
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    procAlertWidget:SetScript("OnLeave", function() GameTooltip:Hide() end)

    procAlertBg = procAlertWidget:CreateTexture(nil, "BACKGROUND")
    procAlertBg:SetAllPoints(procAlertWidget)
    procAlertBg:SetColorTexture(0, 0, 0, 0)

    local icon = procAlertWidget:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(procAlertWidget)
    icon:SetTexture(PROC_TEXTURE_ID)

    local size = math.max(16, math.min(256, cfg.procAlertSize or 64))
    procAlertWidget:SetSize(size, size)
    procAlertWidget:SetPoint("CENTER", UIParent, "CENTER",
        cfg.procAlertPosX or 0, cfg.procAlertPosY or 100)
    procAlertWidget:Hide()
end

local function ApplyProcAlertAppearance()
    if not procAlertWidget then return end
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg  = PWT.db.voidShieldDeck
    local size = math.max(16, math.min(256, cfg.procAlertSize or 64))
    procAlertWidget:SetSize(size, size)
    procAlertWidget:SetFrameStrata(cfg.procAlertStrata or "HIGH")
    procAlertWidget:ClearAllPoints()
    procAlertWidget:SetPoint("CENTER", UIParent, "CENTER",
        cfg.procAlertPosX or 0, cfg.procAlertPosY or 100)
end

-- Show the proc alert (real proc fired — starts the auto-dismiss timer).
function VSD:ShowProcAlert()
    self:BuildProcAlert()
    if not procAlertWidget then return end
    ApplyProcAlertAppearance()
    procAlertWidget:Show()
    self.procAlertActive  = true
    self.procAlertPreview = false
    if procAlertTimer then procAlertTimer:Cancel() end
    procAlertTimer = C_Timer.NewTimer(PROC_ALERT_TIMEOUT, function()
        self:HideProcAlert()
        PWT:Debug("VSD: proc alert auto-dismissed after " .. PROC_ALERT_TIMEOUT .. "s.", "voidshield")
    end)
    PWT:Debug("VSD: proc alert shown.", "voidshield")
end

-- Show a non-timed preview so the user can position the frame from options.
function VSD:ShowProcAlertPreview()
    self:BuildProcAlert()
    if not procAlertWidget then return end
    ApplyProcAlertAppearance()
    procAlertWidget:Show()
    self.procAlertPreview = true
    -- Don't start the timer or set procAlertActive — this is positioning only.
end

-- Hide the proc alert preview without touching a real active alert.
function VSD:HideProcAlertPreview()
    if self.procAlertActive then return end  -- real alert is showing; leave it
    self.procAlertPreview = false
    if procAlertWidget then procAlertWidget:Hide() end
end

function VSD:HideProcAlert()
    self.procAlertActive  = false
    self.procAlertPreview = false
    if procAlertTimer then
        procAlertTimer:Cancel()
        procAlertTimer = nil
    end
    if procAlertWidget then procAlertWidget:Hide() end
end

function VSD:SetProcAlertMovable(enabled)
    if not procAlertWidget then return end
    procAlertWidget:SetMovable(enabled)
    procAlertWidget:EnableMouse(enabled)
    if procAlertBg then
        if enabled then
            procAlertBg:SetColorTexture(0.15, 0.15, 0.15, 0.45)
        else
            procAlertBg:SetColorTexture(0, 0, 0, 0)
        end
    end
end

function VSD:ResetProcAlertPosition()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    PWT.db.voidShieldDeck.procAlertPosX = nil
    PWT.db.voidShieldDeck.procAlertPosY = nil
    if procAlertWidget then
        procAlertWidget:ClearAllPoints()
        procAlertWidget:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
end

-- ─────────────────────────────────────────────────────────────
--  Public API  (called from Core/Init.lua event dispatch)
-- ─────────────────────────────────────────────────────────────

function VSD:OnSpellCast(unit, spellID)
    if unit ~= "player" then return end
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    if not PWT.db.voidShieldDeck.enabled then return end
    if not PWT.isDisc then return end

    -- PWS cast (base or Void Shield proc) while alert is active → dismiss it.
    if spellID == PWS_SPELL_ID or spellID == PWS_PROC_SPELL_ID then
        if self.procAlertActive then self:HideProcAlert() end
        return
    end

    if spellID ~= PENANCE_SPELL_ID then return end
    self:OnPenanceCast()
    C_Timer.After(0.05, function() self:CheckForProc() end)
end

function VSD:OnLogin()
    self:ResetDeck("login")
    pwsSlot = FindPWSSlot()
    if PWT.db and PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled and PWT.isDisc then
        self:ShowWidget()
    end
end

function VSD:OnLeaveCombat()
    -- nothing needed on combat leave
end

function VSD:OnEncounterStart()
    if not PWT.db or not PWT.db.voidShieldDeck or not PWT.db.voidShieldDeck.enabled then return end
    -- ENCOUNTER_START fires for every boss including M+ bosses.
    -- Only reset for raid encounters; M+ runs are handled by OnChallengeModeStart.
    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "raid" then return end
    self:ResetDeck("raid encounter start")
    pwsSlot = FindPWSSlot()
end

function VSD:OnChallengeModeStart()
    if not PWT.db or not PWT.db.voidShieldDeck or not PWT.db.voidShieldDeck.enabled then return end
    self:ResetDeck("Mythic+ start")
    pwsSlot = FindPWSSlot()
end

function VSD:PrintStatus()
    PWT:Print("Void Shield Deck:"
        .. "  enabled="        .. tostring(PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled)
        .. "  cardsRemaining=" .. tostring(self.cardsRemaining)
        .. "  procAvailable="  .. tostring(self.procAvailable)
        .. "  awaiting="       .. tostring(self.awaitingOutcome))
end
