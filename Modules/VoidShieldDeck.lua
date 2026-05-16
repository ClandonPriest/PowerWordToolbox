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
local CAST_HISTORY_MAX   = 50        -- rolling history depth for desync detection
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
VSD.stateInitialized  = false  -- true once RestoreState has run; prevents OnLogin overwriting it
VSD.mPlusEventGuard = true   -- guard ON by default; opened briefly by CHALLENGE_MODE_START, closed again by first WORLD_STATE_TIMER_START (dome drop)

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

-- positionTicker polls UnitPosition every 5s and writes directly to SavedVariables.
-- Writing during gameplay avoids UnitPosition being unreliable at PLAYER_LOGOUT/PLAYER_CAMPING time.
local positionTicker = nil


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
    -- Scan all 180 slots: 1-72 are Blizzard bars, 73-180 are addon bars (Bartender4, Dominos, ElvUI, etc.)
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
    PWT:Debug("Void Shield: +[" .. eventType .. "] cards=" .. VSD.cardsRemaining
        .. " procAvail=" .. tostring(VSD.procAvailable)
        .. " unknown=" .. tostring(VSD.deckUnknown), "voidshield")
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

-- Returns true if ph[base..base+2] is a valid deck: exactly 1 strong P and 2 N (any order).
local function IsValidDeck(ph, base)
    local pCount, nCount, strongP = 0, 0, false
    for i = 0, 2 do
        local e = ph[base + i]
        if not e then return false end
        if e.outcome == "P" then
            pCount = pCount + 1
            if e.isStrong then strongP = true end
        elseif e.outcome == "N" then
            nCount = nCount + 1
        end
    end
    return pCount == 1 and nCount == 2 and strongP
end

-- Detects desync patterns and corrects state when confident enough to do so.
function VSD:CheckDesync()
    local ph = GetPenanceHistory()
    if not self.deckUnknown then return end

    -- Pattern 1: [NNP anchor (strong)] [k×3 penances, k≥0] [P — new proc on card 1 of fresh deck]
    --
    -- ph (newest→oldest): ph[1]=P, ph[s..s+2] is the NNP anchor (ph[s]=P strong, ph[s+1]=N, ph[s+2]=N)
    -- Anchor isStrong: S event exists between anchor proc and next penance in raw history,
    -- confirming the proc was consumed. Prevents an unconsumed NNP proc (buff still active)
    -- from matching as a false anchor.
    -- Intermediate blocks ph[2..s-1]: each group of 3 must be a valid deck (1 strong P + 2 N).
    -- Result: proc is card 1 of new deck, 2 no-procs remain → 0% / 2 cards left.
    if #ph >= 4 and ph[1].outcome == "P" then
        for k = 0, math.floor((#ph - 4) / 3) do
            local s = 2 + k * 3
            if not (ph[s] and ph[s+1] and ph[s+2]) then break end
            if ph[s].outcome=="P" and ph[s].isStrong
               and ph[s+1].outcome=="N" and ph[s+2].outcome=="N" then
                local valid = true
                for j = 0, k - 1 do
                    if not IsValidDeck(ph, 2 + j * 3) then valid = false; break end
                end
                if valid then
                    PWT:Debug("Void Shield: Pattern1 – NNP→P, resynced to 0%/2/3.", "voidshield")
                    self.cardsRemaining       = 2
                    self.procAvailable        = false
                    self.deckUnknown          = false
                    self.deckUnknownAmbiguous = false
                    self:RefreshWidget()
                    return
                end
            end
        end
    end

    -- Pattern 2: [PNN anchor (strong)] [k×3 penances, k≥0] [N N — two no-procs of fresh deck]
    --
    -- ph (newest→oldest): ph[1]=N, ph[2]=N, ph[s..s+2] is the PNN anchor
    -- (ph[s]=N, ph[s+1]=N, ph[s+2]=P strong).
    -- k=0 (ph[1..5]=N,N,N,N,P) subsumes the old "4 consecutive no-procs" pattern.
    -- Intermediate blocks ph[3..s-1]: each group of 3 must be a valid deck (1 strong P + 2 N).
    -- Result: 2 penances drawn (both no-proc), proc must be last card → 100% / 1 card left.
    if #ph >= 5 and ph[1].outcome == "N" and ph[2].outcome == "N" then
        for k = 0, math.floor((#ph - 5) / 3) do
            local s = 3 + k * 3
            if not (ph[s] and ph[s+1] and ph[s+2]) then break end
            if ph[s].outcome=="N" and ph[s+1].outcome=="N"
               and ph[s+2].outcome=="P" and ph[s+2].isStrong then
                local valid = true
                for j = 0, k - 1 do
                    if not IsValidDeck(ph, 3 + j * 3) then valid = false; break end
                end
                if valid then
                    PWT:Debug("Void Shield: Pattern2 – PNN→NN, resynced to 100%/1/3.", "voidshield")
                    self.cardsRemaining       = 1
                    self.procAvailable        = true
                    self.deckUnknown          = false
                    self.deckUnknownAmbiguous = false
                    self:RefreshWidget()
                    return
                end
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

    -- If the old proc was still live at cast time, check whether the texture was already
    -- showing. If so, we can't distinguish old proc still showing vs new proc fired.
    if self.oldProcLive then
        local wasProc = self.procTextureAtCast
        self.oldProcLive       = false
        self.procTextureAtCast = false
        if didProc and wasProc then
            -- Ambiguous boundary: proc texture active at cast and again after — can't tell old vs new.
            -- Count this penance as drawn (2 remain), procAvailable=false keeps skipDetection active
            -- for the remaining 2 cards so false positives from the old proc don't fire.
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
            self:RefreshWidget()
            return
        end
        -- wasProc=false or didProc=false: detection is clean, fall through to record normally.
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

    -- Proc on card 2 while in ambiguous unknown: old proc was consumed before this cast ran,
    -- so this is a genuine new proc. Card 3 is guaranteed no-proc — exit unknown now.
    if self.deckUnknownAmbiguous and didProc and self.cardsRemaining == 1 then
        self.deckUnknown          = false
        self.deckUnknownAmbiguous = false
    end

    if self.cardsRemaining == 0 then
        self:CheckDesync()
        -- CheckDesync may have resynced to non-zero (Pattern 2); only reset if still empty.
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
    -- In any unknown state procAvailable is meaningless; use procUnconsumed as the guard instead.
    -- If a proc is already tracked and not yet consumed, the texture is from that proc — skip
    -- detection. If procUnconsumed=false, no active tracked proc exists and detection is safe.
    local skipDetection = (not self.deckUnknown and not self.procAvailable)
                       or (self.deckUnknown and self.procUnconsumed)
    if skipDetection then
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

    -- ClearAllPoints required on each card — accumulates conflicting anchors if orientation is toggled.
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

    chanceWidget:SetFrameStrata(cfg.chanceStrata or "MEDIUM")
    deckWidget:SetFrameStrata(cfg.deckStrata   or "MEDIUM")
    cardsWidget:SetFrameStrata(cfg.cardsStrata  or "MEDIUM")

    local on = self.widgetVisible
    chanceWidget:SetShown(on and cfg.showChance ~= false)
    deckWidget:SetShown(on and cfg.showDeck ~= false)
    cardsWidget:SetShown(on and cfg.showCards ~= false)

    -- Slots 1 & 2 = no-proc cards, slot 3 = proc card.
    if self.deckUnknown then
        -- Ambiguous unknown tracks cardsRemaining (2 known cards left); full unknown always shows all 3.
        local visibleCards = self.deckUnknownAmbiguous and self.cardsRemaining or MAX_CARDS
        for i = 1, MAX_CARDS do
            if cardTextures[i] then cardTextures[i]:SetShown(i <= visibleCards) end
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
        -- Ambiguous unknown tracks cardsRemaining (2 known cards left); full unknown always shows all 3.
        local visibleCards = self.deckUnknownAmbiguous and self.cardsRemaining or MAX_CARDS
        for i = 1, MAX_CARDS do
            if cardTextures[i] then cardTextures[i]:SetShown(i <= visibleCards) end
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
    local cfg   = PWT.db.voidShieldDeck
    local idx   = cfg.procSoundIndex  or 5
    local entry = soundList[idx]
    local chan  = cfg.procSoundChannel or "SFX"
    if entry and entry.sType == "lsm" then
        PlaySoundFile(entry.path, chan)
    else
        local preset = VSD_SOUNDS[idx] or VSD_SOUNDS[5]
        PlaySound(preset.id, chan, false)
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
            PrintCastHistory()
            self.procUnconsumed = false
            self:CheckDesync()
        end
        return
    end

    if spellID ~= PENANCE_SPELL_ID then return end
    self:OnPenanceCast()
    C_Timer.After(0.05, function() self:CheckForProc() end)
end

-- Writes deck state to SavedVariables. Called on PLAYER_CAMPING (logout) and PLAYER_LOGOUT (reload). Not reached on DC/crash.
function VSD:SaveState()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local vs = PWT.db.voidShieldDeck
    vs.savedCardsRemaining      = self.cardsRemaining
    vs.savedProcAvailable       = self.procAvailable
    vs.savedDeckUnknown         = self.deckUnknown
    vs.savedDeckUnknownAmbiguous = self.deckUnknownAmbiguous
    vs.savedCastHistory = {}
    for i = castHistorySize - 1, 0, -1 do
        vs.savedCastHistory[castHistorySize - i] = GetHistoryEntry(i)
    end
    -- savedWorldX/Y/instanceID are kept current by positionTicker (every 5s); no write needed here.
end

function VSD:RestoreState(isReload)
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local vs = PWT.db.voidShieldDeck
    self.cardsRemaining       = vs.savedCardsRemaining
    self.procAvailable        = vs.savedProcAvailable
    self.deckUnknown          = vs.savedDeckUnknown         or false
    self.deckUnknownAmbiguous = vs.savedDeckUnknownAmbiguous or false
    WipeCastHistory()
    if vs.savedCastHistory then
        for _, v in ipairs(vs.savedCastHistory) do
            if v == true then RecordEvent("P")
            elseif v == false then RecordEvent("N")
            else RecordEvent(v)
            end
        end
    end
    -- Coords are intentionally left — they persist until overwritten by the next PollPosition tick.
    vs.savedCardsRemaining       = nil
    vs.savedProcAvailable        = nil
    vs.savedCastHistory          = nil
    vs.savedDeckUnknown          = nil
    vs.savedDeckUnknownAmbiguous = nil
    self.stateInitialized = true
    local context = isReload and "after a reload" or "after logging in"
    PWT:Print("Void Shield deck state restored " .. context .. ": "
        .. self.cardsRemaining .. "/" .. MAX_CARDS .. " cards remaining.")
end

function VSD:EnterUnknownState(reason, chatMsg)
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
    PWT:Print(chatMsg or "Void Shield Deck Status currently unknown. Waiting for a hard reset condition or pattern match to resync.")
    self:RefreshWidget()
end

local WORLD_POSITION_THRESHOLD = 50  -- yards; large enough for any DC scenario, immune to map hierarchy differences

local function PollPosition()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local posY, posX, _, instanceID = UnitPosition("player")
    if not posX or not posY then return end
    local vs = PWT.db.voidShieldDeck
    vs.savedWorldX     = posX
    vs.savedWorldY     = posY
    vs.savedInstanceID = instanceID or 0
end

-- Returns true (match), false (no match / DC), or nil (position not ready — retry).
local function CheckPositionMatch(vs)
    if not vs.savedWorldX or not vs.savedWorldY then return false end
    local posY, posX, _, instanceID = UnitPosition("player")
    if not posX or not posY then return nil end
    if (instanceID or 0) ~= (vs.savedInstanceID or 0) then return false end
    local dx = posX - vs.savedWorldX
    local dy = posY - vs.savedWorldY
    return math.sqrt(dx * dx + dy * dy) < WORLD_POSITION_THRESHOLD
end

function VSD:OnEnteringWorld(isReload)
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    local vs = PWT.db.voidShieldDeck
    if vs.savedCardsRemaining ~= nil then
        local function TryRestore(isRetry)
            local posMatch = CheckPositionMatch(vs)
            local posY, posX, _, instanceID = UnitPosition("player")
            PWT:Debug(string.format(
                "Void Shield position check: saved=x:%.1f y:%.1f inst:%s  current=x:%.1f y:%.1f inst:%s  dist:%.1f threshold:%d  result:%s",
                vs.savedWorldX or 0, vs.savedWorldY or 0, tostring(vs.savedInstanceID or 0),
                posX or 0, posY or 0, tostring(instanceID or 0),
                (posX and vs.savedWorldX) and math.sqrt((posX - vs.savedWorldX)^2 + (posY - vs.savedWorldY)^2) or -1,
                WORLD_POSITION_THRESHOLD,
                tostring(posMatch)
            ), "voidshield")
            if posMatch then
                self:RestoreState(isReload)
                self:RefreshWidget()
            elseif not isRetry then
                C_Timer.After(0.5, function() TryRestore(true) end)
            else
                if posMatch == false then
                    self:EnterUnknownState(
                        "potential disconnect or crash detected",
                        "Void Shield: Potential disconnect or crash detected. Deck state set to Unknown."
                    )
                else
                    self:EnterUnknownState(
                        "position unavailable after login",
                        "Void Shield: Could not read player position on login. Deck state set to Unknown."
                    )
                end
                vs.savedCardsRemaining = nil
                vs.savedProcAvailable  = nil
                vs.savedCastHistory    = nil
                self:RefreshWidget()
            end
        end
        C_Timer.After(2, function() TryRestore(false) end)
    end
end

function VSD:OnLogin()
    if not PWT.db or not PWT.db.voidShieldDeck then return end

    self:BuildSoundList()
    BuildButtonFrameCache()

    if not positionTicker then
        PollPosition()
        positionTicker = C_Timer.NewTicker(5, PollPosition)
    end

    local vs = PWT.db.voidShieldDeck
    -- Defer to OnEnteringWorld if saved state exists (fresh login: OnEnteringWorld hasn't run yet).
    -- Skip if state was already initialized by OnEnteringWorld (reload: it ran first).
    if vs.savedCardsRemaining ~= nil
       or self.stateInitialized
       or self.deckUnknown then
        pwsSlot = FindPWSSlot()
        if vs.enabled and PWT.isDisc then self:ShowWidget() end
        return
    end
    self:EnterUnknownState("login")
    pwsSlot = FindPWSSlot()
    if vs.enabled and PWT.isDisc then self:ShowWidget() end
end

function VSD:OnSpecChange()
    if not PWT.db or not PWT.db.voidShieldDeck then return end
    pwsSlot = FindPWSSlot()
    if PWT.isDisc and PWT.db.voidShieldDeck.enabled then
        self:ShowWidget()
    else
        self:HideWidget()
    end
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

function VSD:OnChallengeModeArmed()
    -- CHALLENGE_MODE_START fires at key activation (10-sec countdown).
    -- Open the gate so the upcoming dome drop (WORLD_STATE_TIMER_START) can fire the deck reset.
    self.mPlusEventGuard = false
end

function VSD:OnChallengeModeStart()
    if not PWT.db or not PWT.db.voidShieldDeck or not PWT.db.voidShieldDeck.enabled then return end
    if self.mPlusEventGuard then return end
    self.mPlusEventGuard = true
    self:ResetDeck("Mythic+ timer start", true)
    pwsSlot = FindPWSSlot()
end

function VSD:PrintStatus()
    PWT:Print("Void Shield Deck:"
        .. "  enabled="        .. tostring(PWT.db.voidShieldDeck and PWT.db.voidShieldDeck.enabled)
        .. "  cardsRemaining=" .. tostring(self.cardsRemaining)
        .. "  procAvailable="  .. tostring(self.procAvailable)
        .. "  awaiting="       .. tostring(self.awaitingOutcome))
end
