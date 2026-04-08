-- ============================================================
--  Power Word: Toolbox  |  Modules/UtilityReminders.lua
--  Checks for utility talents when entering a tracked dungeon
--  and shows an on-screen alert if any are missing.
-- ============================================================

local _, PWT = ...

PWT.UtilityReminders = {}
local UR = PWT.UtilityReminders

-- ============================================================
--  Data  (shared with Options UI)
-- ============================================================

-- instanceID: GetInstanceInfo() return #8
UR.DUNGEONS = {
    { key = "magisters",         name = "Magister's Terrace",      instanceID = 2811 },
    { key = "maisara",           name = "Maisara Caverns",         instanceID = 2874 },
    { key = "nexuspoint",        name = "Nexus-Point Xenas",       instanceID = 2915},
    { key = "windrunner",        name = "Windrunner Spire",        instanceID = 2805 },
    { key = "algethaar",         name = "Algeth'ar Academy",       instanceID = 2526},
    { key = "seatoftriumvirate", name = "Seat of the Triumvirate", instanceID = 1753 },
    { key = "skyreach",          name = "Skyreach",                instanceID = 1209 },
    { key = "pitofsaron",        name = "Pit of Saron",            instanceID = 656 },
}

-- spellID: IsPlayerSpell(spellID) returns true when the talent is taken.
-- headerLabel: two-line label used in the options table column header.
UR.SPELLS = {
    { key = "shackle",  name = "Shackle Horror",  headerLabel = "Shackle\nHorror",  spellID = 9484   },
    { key = "purify",   name = "Improved Purify", headerLabel = "Improved\nPurify", spellID = 390632 },
    { key = "phantasm", name = "Phantasm",         headerLabel = "Phantasm",         spellID = 108942 },
}

-- ============================================================
--  Fast Lookups
-- ============================================================

local instIDLookup = {}

for _, d in ipairs(UR.DUNGEONS) do
    if d.instanceID then instIDLookup[d.instanceID] = d end
end

-- ============================================================
--  Talent Detection
-- ============================================================

local function GetMissingSpells(dungeonKey)
    local db = PWT.db
    if not db or not db.utilityReminders then return {} end
    local checks = db.utilityReminders.checks[dungeonKey]
    if not checks then return {} end

    local missing = {}
    for _, spell in ipairs(UR.SPELLS) do
        if checks[spell.key] and not IsPlayerSpell(spell.spellID) then
            missing[#missing + 1] = spell
        end
    end
    return missing
end

-- ============================================================
--  Alert Frame  (PI overlay style — no background, bouncing)
-- ============================================================

local MAX_ROWS = 3

local alertFrame  = nil

-- Lay out rows for the given font/icon size and return total frame height.
local function ArrangeRows(size)
    local rowH  = size + 8   -- icon + breathing room
    local iconS = size
    for i, r in ipairs(alertFrame.rows) do
        r.row:SetHeight(rowH)
        r.row:ClearAllPoints()
        r.row:SetPoint("TOPLEFT",  alertFrame, "TOPLEFT",  0, -(i - 1) * rowH)
        r.row:SetPoint("TOPRIGHT", alertFrame, "TOPRIGHT", 0, -(i - 1) * rowH)
        r.icon:SetSize(iconS, iconS)
    end
    return rowH
end

local function BuildAlertFrame()
    if alertFrame then return end

    local db   = PWT.db and PWT.db.utilityReminders
    local initX = db and db.alertPosX
    local initY = db and db.alertPosY

    local f = CreateFrame("Frame", "PWT_URAlert", UIParent)
    f:SetSize(380, 40)   -- placeholder; ArrangeRows sets real height
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    if initX and initY then
        f:SetPoint("CENTER", UIParent, "CENTER", initX, initY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
    f:SetMovable(true)
    f:EnableMouse(false)   -- only enabled during move mode
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x = self:GetLeft()  + self:GetWidth()  / 2 - UIParent:GetWidth()  / 2
        local y = self:GetBottom() + self:GetHeight() / 2 - UIParent:GetHeight() / 2
        if PWT.db and PWT.db.utilityReminders then
            PWT.db.utilityReminders.alertPosX = x
            PWT.db.utilityReminders.alertPosY = y
        end
    end)

    -- Faint background — only visible during move mode
    local previewBg = f:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints(f)
    previewBg:SetColorTexture(0.06, 0.04, 0.10, 0)
    f.previewBg = previewBg

    -- Bounce animation — same pattern as the PI overlay
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

    -- Pre-built spell rows (pool of MAX_ROWS)
    f.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, f)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)

        local lbl = row:CreateFontString(nil, "OVERLAY")
        lbl:SetPoint("LEFT",  icon, "RIGHT", 8, 0)
        lbl:SetPoint("RIGHT", row,  "RIGHT", 0, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetMaxLines(1)
        lbl:SetTextColor(1, 0.85, 0.1, 1)

        row:Hide()
        f.rows[i] = { row = row, icon = icon, lbl = lbl }
    end

    f:Hide()
    alertFrame = f
end

local dismissTimer = nil

function UR:ShowAlert(dungeonName, missing)
    BuildAlertFrame()
    if #missing == 0 then return end

    if dismissTimer then
        dismissTimer:Cancel()
        dismissTimer = nil
    end

    alertFrame.bounceAG:Stop()

    local db   = PWT.db and PWT.db.utilityReminders
    local size = (db and db.alertSize) or 18
    local font = (PWT.db and PWT.db.font) or "Fonts\\FRIZQT__.TTF"
    local rowH = ArrangeRows(size)

    for i = 1, MAX_ROWS do
        local row   = alertFrame.rows[i]
        local spell = missing[i]
        if spell then
            local sInfo = C_Spell.GetSpellInfo(spell.spellID)
            if sInfo and sInfo.iconID then
                row.icon:SetTexture(sInfo.iconID)
            else
                row.icon:SetColorTexture(0.25, 0.25, 0.30, 0.9)
            end
            if not pcall(function() row.lbl:SetFont(font, size, "OUTLINE") end) then
                row.lbl:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
            end
            row.lbl:SetText(spell.name .. " is missing!")
            row.row:Show()
        else
            row.row:Hide()
        end
    end

    alertFrame:SetHeight(#missing * rowH)
    alertFrame:Show()
    alertFrame.bounceAG:Play()

    dismissTimer = C_Timer.NewTimer(30, function()
        alertFrame.bounceAG:Stop()
        alertFrame:Hide()
        dismissTimer = nil
    end)
end

-- ============================================================
--  Move / Resize Mode
-- ============================================================

function UR:SetAlertMovable(canMove)
    BuildAlertFrame()
    local db   = PWT.db and PWT.db.utilityReminders
    local size = (db and db.alertSize) or 18

    if canMove then
        -- Show all spell rows as a preview so the user can see the full size
        alertFrame.bounceAG:Stop()
        local font = (PWT.db and PWT.db.font) or "Fonts\\FRIZQT__.TTF"
        local rowH = ArrangeRows(size)
        for i, row in ipairs(alertFrame.rows) do
            local spell = UR.SPELLS[i]
            if spell then
                local sInfo = C_Spell.GetSpellInfo(spell.spellID)
                if sInfo and sInfo.iconID then row.icon:SetTexture(sInfo.iconID) end
                if not pcall(function() row.lbl:SetFont(font, size, "OUTLINE") end) then
                    row.lbl:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
                end
                row.lbl:SetText(spell.name .. " is missing!")
                row.row:Show()
            end
        end
        alertFrame:SetHeight(#UR.SPELLS * rowH)
        alertFrame.previewBg:SetColorTexture(0.06, 0.04, 0.10, 0.85)
        alertFrame:EnableMouse(true)
        alertFrame:Show()
        alertFrame.bounceAG:Play()
    else
        alertFrame.bounceAG:Stop()
        for _, row in ipairs(alertFrame.rows) do row.row:Hide() end
        alertFrame.previewBg:SetColorTexture(0.06, 0.04, 0.10, 0)
        alertFrame:EnableMouse(false)
        alertFrame:Hide()
    end
end

function UR:ApplyAlertSize(size)
    if not alertFrame then return end
    local db   = PWT.db and PWT.db.utilityReminders
    local font = (PWT.db and PWT.db.font) or "Fonts\\FRIZQT__.TTF"
    local rowH = ArrangeRows(size)
    -- Reapply font on visible rows
    for _, row in ipairs(alertFrame.rows) do
        if not pcall(function() row.lbl:SetFont(font, size, "OUTLINE") end) then
            row.lbl:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
        end
    end
    if alertFrame:IsShown() then
        local count = 0
        for _, row in ipairs(alertFrame.rows) do
            if row.row:IsShown() then count = count + 1 end
        end
        alertFrame:SetHeight(math.max(1, count) * rowH)
    end
end

-- ============================================================
--  Detection
-- ============================================================

local function FindCurrentDungeon()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "party" and instanceID and instanceID ~= 0 then
        return instIDLookup[instanceID]
    end
    return nil
end

local lastCheckTime = 0

function UR:TriggerCheck()
    if not PWT.isPriest then return end
    local db = PWT.db
    if not db or not db.utilityReminders or not db.utilityReminders.enabled then return end

    local now = GetTime()
    if now - lastCheckTime < 60 then return end
    lastCheckTime = now

    local dungeon = FindCurrentDungeon()
    if not dungeon then return end

    PWT:Debug("UtilityReminders: detected '" .. dungeon.name .. "'", "utility")

    local missing = GetMissingSpells(dungeon.key)
    if #missing > 0 then
        self:ShowAlert(dungeon.name, missing)
    else
        PWT:Debug("UtilityReminders: all required talents present.", "utility")
    end
end

function UR:OnLogin()
    -- Intentionally empty — TriggerCheck fires via PLAYER_ENTERING_WORLD.
end

function UR:PrintStatus()
    PWT:Print("Utility Reminders: enabled=" ..
        tostring(PWT.db and PWT.db.utilityReminders and PWT.db.utilityReminders.enabled))
end
