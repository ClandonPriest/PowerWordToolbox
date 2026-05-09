-- Power Word: Toolbox | Modules/VoidShieldDeck.lua
-- Void Shield 3-card deck tracker. Deck = 2 no-proc + 1 proc card.
-- Each Penance cast draws one card; chance = 1/cardsRemaining while proc is in deck.
-- Proc detected by monitoring the PWS action slot texture for the Void Shield icon.

local _, PWT = ...

PWT.VoidShieldDeck = {}
local VSD = PWT.VoidShieldDeck

-- Constants
local PENANCE_SPELL_ID   = 47540
local PWS_SPELL_ID       = 17
local PWS_PROC_SPELL_ID  = 1253593
local BASE_SLOT_TEXTURE  = 135940    -- Power Word: Shield icon
local PROC_TEXTURE_ID    = 7514191   -- Void Shield icon (proc active)
local MAX_CARDS          = 3
local OUTCOME_TIMEOUT    = 0.25      -- seconds to wait before assuming no-proc
local PROC_ALERT_TIMEOUT = 6         -- seconds before proc icon alert auto-dismisses
local CAST_HISTORY_MAX   = 25        -- rolling history depth for desync detection
-- WoW provides 180 action slots total. Slots 1-72 cover Blizzard's default bars;
-- slots 73-180 are used by action bar addons (Bartender4, Dominos, ElvUI, etc.)
-- and must be included so FindPWSSlot works regardless of which bar addon is in use.
local PWS_SLOT_SCAN_MAX  = 180

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

-- Deck State
VSD.cardsRemaining  = MAX_CARDS
VSD.procAvailable   = true   -- proc card is still in the deck
VSD.awaitingOutcome = false  -- true while waiting to detect this cast's result
VSD.pendingCastID   = 0
VSD.widgetVisible   = false  -- true while the module is actively displayed
VSD.procUnconsumed    = false  -- true after proc detected, until PWS_PROC_SPELL_ID fires
VSD.deckUnknown          = false  -- true = show ? and unknown-color cards
VSD.deckUnknownAmbiguous = false  -- true only for ambiguous-proc boundary unknown; the only kind that clears on deck empty
VSD.oldProcLive          = false  -- true when previous deck's proc is still live at deck boundary
VSD.procTextureAtCast = false  -- snapshot: was proc texture active when penance was cast?

-- Widget handles (created lazily in BuildWidget)
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

-- Cast history ring buffer (CAST_HISTORY_MAX slots, O(1) insert).
-- Survives natural deck resets; cleared on login/encounter/challenge resets.
local castHistory     = {}   -- ring buffer slots 1..CAST_HISTORY_MAX
local castHistoryHead = 0    -- index of most recently written slot (0 = empty)
local castHistorySize = 0    -- number of valid entries currently in the buffer

local function GetHistoryEntry(offset)
    if offset >= castHistorySize then return nil end
    local idx = ((castHistoryHead - 1 - offset) % CAST_HISTORY_MAX) + 1
    return castHistory[idx]
end

local function WipeCastHistory()
    wipe(castHistory)
    castHistoryHead = 0
    castHistorySize = 0
end

-- Sound list (built once on login, shared with Options)
local soundList = {}
VSD.soundList   = soundList

-- Button frame cache (built once at login; avoids _G lookups at runtime)
local cachedButtonFrames = {}

local function BuildButtonFrameCache()
    wipe(cachedButtonFrames)
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn and btn.icon then
                cachedButtonFrames[#cachedButtonFrames + 1] = btn
            end
        end
    end
end

-- Proc alert widget (created lazily in BuildProcAlert)
local procAlertWidget  = nil
local procAlertBg      = nil
local procAlertTimer   = nil
VSD.procAlertActive    = false
VSD.procAlertPreview   = false  -- true while showing the positioning preview

-- PWS missing warning popup
local pwsWarningWidget = nil
local pwsWarningTimer  = nil
local PWS_WARN_TIMEOUT = 8

-- Internal helpers

local function ClampFontSize(size)
    return math.max(10, math.min(40, size or 18))
end

local function FormatChance(value)
    return string.format("%d%%", math.floor((value or 0) + 0.5))
end

local function ScanButtonFrames()
    for _, btn in ipairs(cachedButtonFrames) do
        local tex = btn.icon:GetTexture()
        if tex == PROC_TEXTURE_ID or tex == BASE_SLOT_TEXTURE then
            return tex
        end
    end
    return nil
end

local function FindPWSSlot()
    -- Only scan standard action bar slots (1-72); vehicle/override bars (73-180)
    -- will never hold PWS and scanning them is unnecessary work.
    for slot = 1, PWS_SLOT_SCAN_MAX do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and (id == PWS_SPELL_ID or id == PWS_PROC_SPELL_ID) then
            return slot
        end
    end
    PWT:Debug("Void Shield: Power Word: Shield not found on any action bar. Place PWS on your bars for accurate proc tracking.", "voidshield")
    return nil
end

local function IsProcTextureActive()
    local tex
    if pwsSlot then
        tex = GetActionTexture(pwsSlot)
        if not tex then tex = ScanButtonFrames() end
    else
        tex = ScanButtonFrames()
    end
    if not tex then return false end
    return (tex == PROC_TEXTURE_ID)
end

-- Deck logic

function VSD:GetChance()
    if not self.procAvailable then return 0 end
    return self.cardsRemaining > 0 and (100 / self.cardsRemaining) or 0
end

function VSD:ResetDeck(reason, forceKnown)
    self.cardsRemaining  = MAX_CARDS
    self.procAvailable   = true
    self.awaitingOutcome = false
    self.pendingCastID   = 0
    if pendingTimer then
        pendingTimer:Cancel()
        pendingTimer = nil
    end
    if forceKnown then
        self.deckUnknown          = false
        self.deckUnknownAmbiguous = false
        self.oldProcLive          = false
    elseif reason == "deck empty" then
        -- Only clear unknown if it was set by the ambiguous-proc boundary case, where we
        -- deliberately counted 2 remaining cards and expect a natural exhaust. All other
        -- unknown states (login, position mismatch, module enable) must persist until a
        -- hard resync event (pattern match, encounter start, M+ start).
        if self.deckUnknownAmbiguous then
            self.deckUnknown          = false
            self.deckUnknownAmbiguous = false
        end
        -- If the old proc is still unconsumed, mark it so the next penance can detect
        -- ambiguity (proc texture active before cast = can't tell old vs new proc).
        self.oldProcLive = self.procUnconsumed
    end
    self.procUnconsumed = false
    if reason ~= "deck empty" then
        WipeCastHistory()
    end
    self:HideProcAlert()
    self:RefreshWidget()
end

local function RecordEvent(eventType)
    castHistoryHead = (castHistoryHead % CAST_HISTORY_MAX) + 1
    castHistory[castHistoryHead] = eventType
    if castHistorySize < CAST_HISTORY_MAX then castHistorySize = castHistorySize + 1 end
end

-- Returns true if the proc at rawOffset `procOffset` was consumed (S appeared)
-- before the next penance event (i.e., an S exists at a smaller offset than procOffset).
local function IsProcStrong(procOffset)
    for i = procOffset - 1, 0, -1 do
        local e = GetHistoryEntry(i)
        if e == "S" then return true end
        if e == "P" or e == "N" then return false end
    end
    return false
end

-- Returns ordered list (newest first) of penance-only entries, each with
-- { outcome="P"|"N", rawOffset=int, isStrong=bool|nil }
local function GetPenanceHistory()
    local result = {}
    for i = 0, castHistorySize - 1 do
        local e = GetHistoryEntry(i)
        if e == "P" or e == "N" then
            result[#result + 1] = {
                outcome  = e,
                rawOffset = i,
                isStrong = (e == "P") and IsProcStrong(i) or nil,
            }
        end
    end
    return result
end

-- True if ph[startIdx..startIdx+2] form a valid deck (exactly 1 P, 2 N).
local function IsValidDeck(ph, startIdx)
    if not (ph[startIdx] and ph[startIdx+1] and ph[startIdx+2]) then return false end
    local p = 0
    for i = startIdx, startIdx+2 do if ph[i].outcome == "P" then p = p + 1 end end
    return p == 1
end

-- Returns the P entry within ph[startIdx..startIdx+2], or nil.
local function GetDeckProc(ph, startIdx)
    for i = startIdx, startIdx+2 do
        if ph[i] and ph[i].outcome == "P" then return ph[i] end
    end
end

-- Detects desync patterns and corrects state when confident enough to do so.
function VSD:CheckDesync()
    local ph = GetPenanceHistory()

    -- Pattern 1: 4 consecutive no-procs → proc card must still be in deck
    if #ph >= 4 then
        if ph[1].outcome=="N" and ph[2].outcome=="N"
           and ph[3].outcome=="N" and ph[4].outcome=="N" then
            PWT:Debug("Void Shield: 4 no-proc pattern – resynced to 1/3 cards remaining.", "voidshield")
            if self.cardsRemaining ~= 1 or self.procAvailable ~= true then
                self.cardsRemaining       = 1
                self.procAvailable        = true
                self.deckUnknown          = false
                self.deckUnknownAmbiguous = false
                self:RefreshWidget()
            end
            return
        end
    end

    -- Pattern 2: 2 consecutive strong procs → most recent proc was first card of current deck.
    -- No N between them means ph[1] is the first and only penance drawn in the current deck.
    -- Result: 2 no-proc cards remain, proc consumed. Only fires mid-deck (cardsRemaining > 0).
    if self.cardsRemaining > 0 and #ph >= 2 then
        if ph[1].outcome=="P" and ph[1].isStrong
           and ph[2].outcome=="P" and ph[2].isStrong then
            PWT:Debug("Void Shield: 2 consecutive strong procs – resynced to 0% / 2/3.", "voidshield")
            self.cardsRemaining       = 2
            self.procAvailable        = false
            self.deckUnknown          = false
            self.deckUnknownAmbiguous = false
            self:RefreshWidget()
            return
        end
    end

    -- Pattern 3: 2 complete decks visible at deck exhaustion, both procs strong.
    -- Clears procUnconsumed so the upcoming ResetDeck("deck empty") produces a known fresh deck.
    if #ph >= 6 then
        if IsValidDeck(ph,1) and IsValidDeck(ph,4) then
            local p1, p2 = GetDeckProc(ph,1), GetDeckProc(ph,4)
            if p1 and p1.isStrong and p2 and p2.isStrong then
                PWT:Debug("Void Shield: 2-deck boundary confirmed – fresh deck will be known.", "voidshield")
                self.procUnconsumed = false
                return
            end
        end
    end
end

local function PrintCastHistory()
    if not (PWT.db and PWT.db.debug) then return end
    if castHistorySize == 0 then return end
    local parts = {}
    for i = castHistorySize - 1, 0, -1 do
        parts[castHistorySize - i] = GetHistoryEntry(i) or "?"
    end
    PWT:Debug("Void Shield cast history (oldest->newest): [" .. table.concat(parts, ", ") .. "]", "voidshield")
end

function VSD:PrintHistory()
    if castHistorySize == 0 then
        PWT:Print("Void Shield: cast history is empty.")
        return
    end
    local parts = {}
    for i = castHistorySize - 1, 0, -1 do
        parts[castHistorySize - i] = GetHistoryEntry(i) or "?"
    end
    PWT:Print("Void Shield cast history (oldest->newest): [" .. table.concat(parts, ", ") .. "]")
end

function VSD:ApplyCastResult(didProc)
    self.awaitingOutcome = false
    if pendingTimer then
        pendingTimer:Cancel()
        pendingTimer = nil
    end

    -- If the previous deck's proc was still live when this penance was cast,
    -- check whether the proc texture was already showing at cast time.
    -- If it was, we can't distinguish old proc still showing vs new proc fired.
    if self.oldProcLive then
        local wasProc = self.procTextureAtCast
        self.oldProcLive       = false
        self.procTextureAtCast = false
        if didProc and wasProc then
            -- This penance drew card 1 of the new deck while the old proc was still
            -- active. We can't tell if the proc texture is the old proc or a new one.
            -- Enter unknown state, but count this penance as already drawn (2 remain),
            -- and set procAvailable=false so the 2 remaining cards use the early-return
            -- path — keeping the deck countdown correct without false proc detections.
            self.cardsRemaining       = MAX_CARDS - 1
            self.procAvailable        = false
            self.procUnconsumed       = true
            self.deckUnknown          = true
            self.deckUnknownAmbiguous = true
            self.awaitingOutcome      = false
            self.pendingCastID   = 0
            if pendingTimer then pendingTimer:Cancel(); pendingTimer = nil end
            WipeCastHistory()
            self:HideProcAlert()
            PWT:Debug("Void Shield: unknown state - ambiguous proc at deck boundary", "voidshield")
            PWT:Print("Void Shield Deck Status currently unknown. Waiting for a hard reset condition or pattern match to resync.")
            self:RefreshWidget()
            return
        end
        -- wasProc=false: old proc was consumed/expired before this penance; detection is clean.
        -- didProc=false: no new proc regardless; fall through to record N.
    end

    if didProc then
        self.procUnconsumed = true
        self.procAvailable = false
        PWT:Debug("Void Shield proc detected. Cards remaining: " .. (self.cardsRemaining - 1) .. "/" .. MAX_CARDS, "voidshield")
        if PWT.db and PWT.db.voidShieldDeck then
            local cfg = PWT.db.voidShieldDeck
            if cfg.procAlertEnabled then self:ShowProcAlert() end
            if cfg.procSoundEnabled then self:PlayProcSound() end
        end
    end
    self.cardsRemaining = math.max(0, self.cardsRemaining - 1)

    -- Record the outcome AFTER state is updated so CheckDesync sees current values.
    RecordEvent(didProc and "P" or "N")
    PrintCastHistory()

    if self.cardsRemaining == 0 then
        -- Check patterns before resetting — history still contains this outcome.
        self:CheckDesync()
        -- Only reset if CheckDesync didn't correct the state to a non-zero count.
        -- If it did correct it, the deck is mid-run and should not be reset.
        if self.cardsRemaining == 0 then
            self:ResetDeck("deck empty")
        else
            self:RefreshWidget()
        end
    else
        self:CheckDesync()
        self:RefreshWidget()
    end
end

function VSD:CheckForProc()
    if not self.awaitingOutcome then return end
    if IsProcTextureActive() then
        self:ApplyCastResult(true)
    end
end

function VSD:OnPenanceCast()
    if not self.procAvailable then
        self.cardsRemaining = math.max(0, self.cardsRemaining - 1)
        RecordEvent("N")
        PrintCastHistory()
        if self.cardsRemaining == 0 then
            self:ResetDeck("deck empty")
        else
            self:CheckDesync()
            self:RefreshWidget()
        end
        return
    end

    if pwsSlot then
        local actionType, id = GetActionInfo(pwsSlot)
        if not (actionType == "spell" and (id == PWS_SPELL_ID or id == PWS_PROC_SPELL_ID)) then
            pwsSlot = nil
        end
    end
    if not pwsSlot then pwsSlot = FindPWSSlot() end
    if not pwsSlot then self:ShowPWSWarning() end

    -- Snapshot proc texture state before the penance resolves.
    -- Used in ApplyCastResult to detect old-proc contamination.
    self.procTextureAtCast = self.oldProcLive and IsProcTextureActive() or false

    self.awaitingOutcome = true
    self.pendingCastID   = self.pendingCastID + 1
    local castID         = self.pendingCastID

    if pendingTimer then pendingTimer:Cancel() end
    pendingTimer = C_Timer.NewTimer(OUTCOME_TIMEOUT, function()
        if self.awaitingOutcome and self.pendingCastID == castID then
            self:CheckForProc()
            if self.awaitingOutcome then
                self:ApplyCastResult(false)
            end
        end
    end)
end

-- Widget

local DEFAULT_CARD_COLORS = {
    proc    = {0.15, 0.75, 0.25, 1.0},
    noProc  = {0.80, 0.15, 0.15, 1.0},
    unknown = {0.55, 0.52, 0.60, 1.0},
}

function VSD:GetCardColor(kind)
    local cfg = PWT.db and PWT.db.voidShieldDeck
    local key = kind == "proc" and "cardProcColor"
        or kind == "unknown" and "cardUnknownColor"
        or "cardNoProcColor"
    local fallback = DEFAULT_CARD_COLORS[kind] or DEFAULT_CARD_COLORS.noProc
    local col = cfg and cfg[key] or fallback
    return col[1] or fallback[1], col[2] or fallback[2], col[3] or fallback[3], col[4] or fallback[4] or 1.0
end

local function ApplyCardColors()
    if VSD.deckUnknown then
        for i = 1, MAX_CARDS do
            if cardTextures[i] then cardTextures[i]:SetColorTexture(VSD:GetCardColor("unknown")) end
        end
    else
        if cardTextures[1] then cardTextures[1]:SetColorTexture(VSD:GetCardColor("noProc")) end
        if cardTextures[2] then cardTextures[2]:SetColorTexture(VSD:GetCardColor("noProc")) end
        if cardTextures[3] then cardTextures[3]:SetColorTexture(VSD:GetCardColor("proc"))   end
    end
end

local function MakeSubWidget(frameName, posXKey, posYKey)
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(false)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
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
        card:SetPoint("LEFT", cardsWidget, "LEFT", (i - 1) * 34, 2)
        cardTextures[i] = card
    end
    ApplyCardColors()

    chanceWidget:Hide()
    deckWidget:Hide()
    cardsWidget:Hide()
end

-- Full layout update (font, size, position, strata, orientation). Expensive; not called per-cast.
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
    ApplyCardColors()

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
    local chanceText
    if self.deckUnknown then
        chanceText = cfg.showChanceLabel ~= false and "Chance: ?" or "?"
    else
        local chanceVal = FormatChance(self:GetChance())
        chanceText = cfg.showChanceLabel ~= false and ("Chance: " .. chanceVal) or chanceVal
    end
    chanceLabel:SetText(chanceText)
    chanceWidget:SetSize(math.max(60, chanceLabel:GetStringWidth() + 10), chanceFontSz + 10)

    -- Deck count
    deckLabel:SetFont(fontPath, deckFontSz, "OUTLINE")
    local cards = self.cardsRemaining or MAX_CARDS
    local deckText
    if self.deckUnknown then
        deckText = cfg.showDeckLabel ~= false and ("Deck: ? / " .. MAX_CARDS) or ("? / " .. MAX_CARDS)
    else
        local deckVal = cards .. " / " .. MAX_CARDS
        deckText = cfg.showDeckLabel ~= false and ("Deck: " .. deckVal) or deckVal
    end
    deckLabel:SetText(deckText)
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
    -- Slots 1 & 2 = no-proc cards, slot 3 = proc card.
    if self.deckUnknown then
        for i = 1, MAX_CARDS do
            if cardTextures[i] then cardTextures[i]:SetShown(i <= self.cardsRemaining) end
        end
    else
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
end

-- Lightweight per-cast refresh — updates labels, sizes, and card visibility only.
function VSD:RefreshWidget()
    if not chanceWidget then return end
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg = PWT.db.voidShieldDeck

    local chanceFontSz = ClampFontSize(cfg.chanceFontSize)
    local deckFontSz   = ClampFontSize(cfg.deckFontSize)
    ApplyCardColors()

    -- Chance label text + resize to fit new text.
    local chanceText
    if self.deckUnknown then
        chanceText = cfg.showChanceLabel ~= false and "Chance: ?" or "?"
    else
        local chanceVal = FormatChance(self:GetChance())
        chanceText = cfg.showChanceLabel ~= false and ("Chance: " .. chanceVal) or chanceVal
    end
    chanceLabel:SetText(chanceText)
    chanceWidget:SetSize(math.max(60, chanceLabel:GetStringWidth() + 10), chanceFontSz + 10)

    -- Deck label text + resize to fit new text.
    local cards = self.cardsRemaining or MAX_CARDS
    local deckText
    if self.deckUnknown then
        deckText = cfg.showDeckLabel ~= false and ("Deck: ? / " .. MAX_CARDS) or ("? / " .. MAX_CARDS)
    else
        local deckVal = cards .. " / " .. MAX_CARDS
        deckText = cfg.showDeckLabel ~= false and ("Deck: " .. deckVal) or deckVal
    end
    deckLabel:SetText(deckText)
    deckWidget:SetSize(math.max(60, deckLabel:GetStringWidth() + 10), deckFontSz + 10)

    -- Card slot visuals.
    if self.deckUnknown then
        for i = 1, MAX_CARDS do
            if cardTextures[i] then cardTextures[i]:SetShown(i <= self.cardsRemaining) end
        end
    else
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

-- Proc Alert

function VSD:BuildSoundList()
    wipe(soundList)
    local seen = {}
    for _, s in ipairs(VSD_SOUNDS) do
        soundList[#soundList + 1] = { label = s.label, sType = "preset", id = s.id }
        seen[s.label] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local lsmSounds = LSM:List("sound")
        if lsmSounds then
            table.sort(lsmSounds)
            for _, name in ipairs(lsmSounds) do
                local path = LSM:Fetch("sound", name)
                if not seen[name] and path then
                    soundList[#soundList + 1] = { label = name, sType = "lsm", path = path }
                    seen[name] = true
                end
            end
        end
    end
end

function VSD:PlayProcSound()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local cfg  = PWT.db.voidShieldDeck
    local idx  = cfg.procSoundIndex  or 5
    local entry = soundList[idx]
    local vol  = cfg.procSoundVolume  or 1.0
    local chan  = cfg.procSoundChannel or "SFX"

    -- SetCVar is expensive; skip if volume is already at the desired level.
    local prev = GetCVar("Sound_SFXVolume")
    local needsVolChange = math.abs((tonumber(prev) or 1.0) - vol) > 0.001
    if needsVolChange then SetCVar("Sound_SFXVolume", tostring(vol)) end

    if entry and entry.sType == "lsm" then
        PlaySoundFile(entry.path, chan)
    else
        local preset = VSD_SOUNDS[idx] or VSD_SOUNDS[5]
        PlaySound(preset.id, chan, false)
    end

    if needsVolChange then
        C_Timer.After(0.5, function() SetCVar("Sound_SFXVolume", prev) end)
    end
end

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

    procAlertWidget:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
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
    end)
end

-- Non-timed preview for positioning from options; doesn't set procAlertActive.
function VSD:ShowProcAlertPreview()
    self:BuildProcAlert()
    if not procAlertWidget then return end
    ApplyProcAlertAppearance()
    procAlertWidget:Show()
    self.procAlertPreview = true
    -- Don't start the timer or set procAlertActive — this is positioning only.
end

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

-- PWS Missing Warning

local function BuildPWSWarning()
    if pwsWarningWidget then return end

    pwsWarningWidget = CreateFrame("Frame", "PWT_VSDPWSWarning", UIParent)
    pwsWarningWidget:SetSize(360, 50)
    pwsWarningWidget:SetFrameStrata("HIGH")
    pwsWarningWidget:SetClampedToScreen(true)
    pwsWarningWidget:SetPoint("TOP", UIParent, "TOP", 0, -180)

    local icon = pwsWarningWidget:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("LEFT", pwsWarningWidget, "LEFT", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_PowerWordShield")

    local label = pwsWarningWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("LEFT",  pwsWarningWidget, "LEFT", 52, 0)
    label:SetPoint("RIGHT", pwsWarningWidget, "RIGHT", 0, 0)
    label:SetPoint("TOP",   pwsWarningWidget, "TOP", 0, 0)
    label:SetPoint("BOTTOM",pwsWarningWidget, "BOTTOM", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetTextColor(1, 0.85, 0.1, 1)
    label:SetText("Power Word: Shield not found on action bars")
    local font = (PWT.db and PWT.db.font ~= "" and PWT.db.font) or "Fonts\\FRIZQT__.TTF"
    if not pcall(function() label:SetFont(font, 18, "OUTLINE") end) then
        label:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    end
    pwsWarningWidget.label = label

    pwsWarningWidget:Hide()
end

function VSD:ShowPWSWarning()
    BuildPWSWarning()
    if not pwsWarningWidget then return end
    pwsWarningWidget:Show()
    if pwsWarningTimer then pwsWarningTimer:Cancel() end
    pwsWarningTimer = C_Timer.NewTimer(PWS_WARN_TIMEOUT, function()
        if pwsWarningWidget then pwsWarningWidget:Hide() end
        pwsWarningTimer = nil
    end)
end

function VSD:HidePWSWarning()
    if pwsWarningTimer then
        pwsWarningTimer:Cancel()
        pwsWarningTimer = nil
    end
    if pwsWarningWidget then pwsWarningWidget:Hide() end
end

-- Public API

function VSD:OnSpellCast(unit, spellID)
    if unit ~= "player" then return end
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    if not PWT.db.voidShieldDeck.enabled then return end
    if not PWT.isDisc then return end

    -- PWS cast (base or Void Shield proc) while alert is active → dismiss it.
    if spellID == PWS_SPELL_ID or spellID == PWS_PROC_SPELL_ID then
        if self.procAlertActive then self:HideProcAlert() end
        if spellID == PWS_PROC_SPELL_ID then
            self.oldProcLive = false  -- proc consumed; next penance detection is clean
            RecordEvent("S")
            self.procUnconsumed = false
            self:CheckDesync()
        end
        return
    end

    if spellID ~= PENANCE_SPELL_ID then return end
    self:OnPenanceCast()
    C_Timer.After(0.05, function() self:CheckForProc() end)
end

-- Writes deck state to SavedVariables. Only reached on /reload, not DC.
function VSD:SaveState()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local vs = PWT.db.voidShieldDeck
    vs.savedCardsRemaining = self.cardsRemaining
    vs.savedProcAvailable  = self.procAvailable
    vs.savedCastHistory = {}
    for i = castHistorySize - 1, 0, -1 do
        vs.savedCastHistory[castHistorySize - i] = GetHistoryEntry(i)
    end
    -- Save current player coordinates
    local mapID = C_Map.GetBestMapForUnit("player")
    vs.savedMapID = mapID or 0
    vs.savedX = 0
    vs.savedY = 0
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and y then
                vs.savedX = x
                vs.savedY = y
            end
        end
    end
end

function VSD:RestoreState()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local vs = PWT.db.voidShieldDeck
    self.cardsRemaining = vs.savedCardsRemaining
    self.procAvailable  = vs.savedProcAvailable
    self.deckUnknown    = false
    WipeCastHistory()
    if vs.savedCastHistory then
        for _, v in ipairs(vs.savedCastHistory) do
            if v == true then RecordEvent("P")
            elseif v == false then RecordEvent("N")
            else RecordEvent(v)
            end
        end
    end
    -- Consume the saved state so it is not reapplied on a subsequent real login.
    vs.savedCardsRemaining = nil
    vs.savedProcAvailable  = nil
    vs.savedCastHistory    = nil
    vs.savedMapID = nil; vs.savedX = nil; vs.savedY = nil
    PWT:Print("Void Shield deck state restored after reload: "
        .. self.cardsRemaining .. "/" .. MAX_CARDS .. " cards remaining.")
end

function VSD:EnterUnknownState(reason)
    self.cardsRemaining       = MAX_CARDS
    self.procAvailable        = true
    self.deckUnknown          = true
    self.deckUnknownAmbiguous = false
    self.procUnconsumed       = false
    self.oldProcLive          = false
    self.procTextureAtCast    = false
    self.awaitingOutcome      = false
    self.pendingCastID     = 0
    if pendingTimer then pendingTimer:Cancel(); pendingTimer = nil end
    WipeCastHistory()
    self:HideProcAlert()
    PWT:Debug("Void Shield: unknown state" .. (reason and (" - " .. reason) or ""), "voidshield")
    PWT:Print("Void Shield Deck Status currently unknown. Waiting for a hard reset condition or pattern match to resync.")
    self:RefreshWidget()
end

local POSITION_THRESHOLD = 0.005
local function CheckPositionMatch(vs)
    if not vs.savedMapID or vs.savedMapID == 0 then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID ~= vs.savedMapID then return false end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return false end
    local x, y = pos:GetXY()
    if not x or not y then return false end
    return math.abs(x - (vs.savedX or 0)) < POSITION_THRESHOLD
        and math.abs(y - (vs.savedY or 0)) < POSITION_THRESHOLD
end

function VSD:OnEnteringWorld(isReload)
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local vs = PWT.db.voidShieldDeck
    if isReload and vs.savedCardsRemaining ~= nil then
        if CheckPositionMatch(vs) then
            self:RestoreState()
        else
            self:EnterUnknownState("position mismatch on reload")
            vs.savedCardsRemaining = nil
            vs.savedProcAvailable  = nil
            vs.savedCastHistory    = nil
            vs.savedMapID = nil; vs.savedX = nil; vs.savedY = nil
        end
        self:RefreshWidget()
    end
    -- Fresh logins and reloads without saved state are handled by OnLogin below.
end

function VSD:OnLogin()
    if not PWT.db or not PWT.db.voidShieldDeck then return end

    self:BuildSoundList()
    BuildButtonFrameCache()

    local vs = PWT.db.voidShieldDeck
    -- Already in a known/unknown state from OnEnteringWorld — don't overwrite.
    if (vs.savedCardsRemaining == nil and self.cardsRemaining ~= MAX_CARDS)
       or self.deckUnknown then
        pwsSlot = FindPWSSlot()
        if vs.enabled and PWT.isDisc then self:ShowWidget() end
        return
    end
    self:EnterUnknownState("login")
    pwsSlot = FindPWSSlot()
    if vs.enabled and PWT.isDisc then self:ShowWidget() end
end

function VSD:OnLeaveCombat()
    -- nothing needed on combat leave
end

function VSD:OnEncounterStart()
    if not PWT.db or not PWT.db.voidShieldDeck or not PWT.db.voidShieldDeck.enabled then return end
    -- ENCOUNTER_START fires for every Raid boss
    -- Only reset for raid encounters; M+ runs are handled by OnChallengeModeStart.
    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "raid" then return end
    self:ResetDeck("raid encounter start", true)
    pwsSlot = FindPWSSlot()
end

function VSD:OnChallengeModeStart()
    if not PWT.db or not PWT.db.voidShieldDeck or not PWT.db.voidShieldDeck.enabled then return end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
       and not C_ChallengeMode.IsChallengeModeActive() then
        return
    end
    self:ResetDeck("Mythic+ timer start", true)
    pwsSlot = FindPWSSlot()
end

function VSD:OnChallengeModeArmed()
    -- CHALLENGE_MODE_START fires when the key is activated and the 10 second
    -- waiting-room countdown begins. Void Shield resets when the timer starts,
    -- handled by WORLD_STATE_TIMER_START.
end

function VSD:PrintStatus()
    PWT:Print("Void Shield Deck:"
        .. "  enabled="        .. tostring(PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled)
        .. "  cardsRemaining=" .. tostring(self.cardsRemaining)
        .. "  procAvailable="  .. tostring(self.procAvailable)
        .. "  awaiting="       .. tostring(self.awaitingOutcome))
end
