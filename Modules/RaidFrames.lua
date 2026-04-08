-- ============================================================
--  Power Word: Toolbox  |  Modules/RaidFrames.lua
--  Finds a raid/party frame for a given unit token across all
--  supported raid frame addons.
-- ============================================================

local _, PWT = ...

PWT.RaidFrames = {}
local RF = PWT.RaidFrames

function RF:Find(unitToken)
    -- 1) Grid2
    if Grid2Frame and Grid2Frame.activatedFrames then
        for frame, unit in next, Grid2Frame.activatedFrames do
            if UnitIsUnit(unit, unitToken) then
                PWT:Debug("Grid2 frame found for unit: " .. unitToken, "pi")
                return frame
            end
        end
    end

    -- 2) Danders (public API v3.1.8+)
    if DandersFrames and DandersFrames.Api and DandersFrames.Api.GetFrameForUnit then
        local f = DandersFrames.Api.GetFrameForUnit(unitToken)
        if f then
            PWT:Debug("Danders frame found for unit: " .. unitToken, "pi")
            return f
        end
    end

    -- 3) Cell
    if Cell and Cell.unitButtons then
        for _, groupType in ipairs({ "raid", "party" }) do
            local buttons = Cell.unitButtons[groupType]
            if buttons then
                for _, btn in pairs(buttons) do
                    if btn and btn.unit and UnitIsUnit(btn.unit, unitToken) then
                        PWT:Debug("Cell " .. groupType .. " frame found for unit: " .. unitToken, "pi")
                        return btn
                    end
                end
            end
        end
    end

    -- 4) ElvUI
    if ElvUF_Parent then
        for i = 1, 8 do
            local group = _G["ElvUF_RaidGroup" .. i]
            if group then
                for j = 1, group:GetNumChildren() do
                    local child = select(j, group:GetChildren())
                    if child and child.unit and UnitIsUnit(child.unit, unitToken) then
                        PWT:Debug("ElvUI raid frame found for unit: " .. unitToken, "pi")
                        return child
                    end
                end
            end
        end
        local partyGroup = _G["ElvUF_PartyGroup1"]
        if partyGroup then
            for j = 1, partyGroup:GetNumChildren() do
                local child = select(j, partyGroup:GetChildren())
                if child and child.unit and UnitIsUnit(child.unit, unitToken) then
                    PWT:Debug("ElvUI party frame found for unit: " .. unitToken, "pi")
                    return child
                end
            end
        end
    end

    -- 5) Blizzard CompactRaidFrames
    if CompactRaidFrameContainer then
        local i = 1
        while true do
            local f = _G["CompactRaidFrame" .. i]
            if not f then break end
            if f.unit and UnitIsUnit(f.unit, unitToken) then
                PWT:Debug("Blizzard raid frame found for unit: " .. unitToken, "pi")
                return f
            end
            i = i + 1
        end
        for j = 1, 4 do
            local f = _G["CompactPartyFrame_Member" .. j]
            if f and f.unit and UnitIsUnit(f.unit, unitToken) then
                PWT:Debug("Blizzard party frame found for unit: " .. unitToken, "pi")
                return f
            end
        end
    end

    PWT:Debug("No frame found for unit: " .. unitToken ..
        " (Grid2="    .. tostring(Grid2Frame ~= nil) ..
        " Danders="   .. tostring(DandersFrames ~= nil) ..
        " Cell="      .. tostring(Cell ~= nil) ..
        " ElvUI="     .. tostring(ElvUF_Parent ~= nil) ..
        " Blizzard="  .. tostring(CompactRaidFrameContainer ~= nil) .. ")", "pi")
    return nil
end