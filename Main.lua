ReUI.Require
{
    "ReUI.Core >= 1.1.0",
    "ReUI.Actions >= 1.2.0",
}

function Main(isReplay)
    -- No replay guard: in replays, focusing on a player's POV means
    -- GetSelectedUnits and ReUI.Units.Get operate on that player's
    -- units, so "Select Fighters" is genuinely useful while spectating.

    -- ================================================================
    -- PINNED SET
    -- Keys are entity ID strings. Pinned air combat units are excluded
    -- from the select hotkeys. Dead units left in here are harmless
    -- ?hey won't appear in the live unit list.
    -- ================================================================
    local pinned = {}

    -- ================================================================
    -- HELPERS
    -- ================================================================

    local function IsFighter(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        -- Pure air-superiority units only:
        --   T1 Interceptors, Aeon T2 Combat Fighter (XAA0202), T3 ASFs.
        -- The BOMBER exclusion drops the T2 Fighter/Bombers
        -- (DEA0202, DRA0202, XSA0202, XNA0202), which also carry
        -- ANTIAIR + HIGHALTAIR but are dual-role ground attackers.
        -- The Aeon Combat Fighter has no BOMBER category, so it stays.
        return cats ~= nil
            and cats['HIGHALTAIR'] ~= nil
            and cats['ANTIAIR'] ~= nil
            and cats['BOMBER'] == nil
            and cats['EXPERIMENTAL'] == nil
    end

    local function IsBomber(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        return cats ~= nil
            and cats['BOMBER'] ~= nil
            and cats['EXPERIMENTAL'] == nil
    end

    local function IsGunship(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        return cats ~= nil
            and cats['GROUNDATTACK'] ~= nil
            and cats['ANTIAIR'] == nil
            and cats['BOMBER'] == nil
            and cats['EXPERIMENTAL'] == nil
    end

    local function IsAirCombatUnit(unit)
        return IsFighter(unit) or IsBomber(unit) or IsGunship(unit)
    end

    local function GetEntityId(unit)
        local ok, eid = pcall(function() return unit:GetEntityId() end)
        if ok then return eid end
        return nil
    end

    -- ================================================================
    -- SELECT FIGHTERS
    -- Selects all own fighters that are not currently pinned out.
    --
    -- Note: this reads ReUI's cached unit list, which can lag by a few
    -- seconds for units that were just share-transferred from an ally.
    -- An attempt to bypass the cache with engine-native
    -- UISelectionByCategory was tried and failed silently in this
    -- context, so we stay with the cached path.
    -- ================================================================
    local function SelectFighters(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        for _, unit in allUnits do
            if IsFighter(unit) then
                local eid = GetEntityId(unit)
                if eid and not pinned[eid] then
                    table.insert(toSelect, unit)
                end
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        end
    end

    local function SelectBombers(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        for _, unit in allUnits do
            if IsBomber(unit) then
                local eid = GetEntityId(unit)
                if eid and not pinned[eid] then
                    table.insert(toSelect, unit)
                end
            end
        end
        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        end
    end

    local function SelectGunships(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        for _, unit in allUnits do
            if IsGunship(unit) then
                local eid = GetEntityId(unit)
                if eid and not pinned[eid] then
                    table.insert(toSelect, unit)
                end
            end
        end
        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        end
    end

    -- ================================================================
    -- TOGGLE PIN
    -- Looks at all selected fighters, gunships, and bombers.
    -- If ANY of them are pinned -> unpin ALL of them.
    -- If NONE are pinned       -> pin ALL of them.
    -- Non-air-combat units in the selection are ignored.
    -- ================================================================
    local function TogglePin(_sel)
        local sel = GetSelectedUnits()
        if not sel then return end

        -- Collect selected air combat units only
        local airCombatUnits = {}
        for _, unit in sel do
            if IsAirCombatUnit(unit) then
                table.insert(airCombatUnits, unit)
            end
        end

        if table.getn(airCombatUnits) == 0 then return end

        -- Check if any selected air combat unit is currently pinned
        local anyPinned = false
        for _, unit in airCombatUnits do
            local eid = GetEntityId(unit)
            if eid and pinned[eid] then
                anyPinned = true
                break
            end
        end

        -- If any were pinned: unpin all. Otherwise: pin all.
        for _, unit in airCombatUnits do
            local eid = GetEntityId(unit)
            if eid then
                if anyPinned then
                    pinned[eid] = nil
                else
                    pinned[eid] = true
                end
            end
        end
    end

    -- ================================================================
    -- REGISTER HOTKEYS
    -- ================================================================
    ReUI.Actions.SelectionAction("Select Fighters", SelectFighters, "Improved Air Selection")
    ReUI.Actions.SelectionAction("Select Bombers", SelectBombers, "Improved Air Selection")
    ReUI.Actions.SelectionAction("Select Gunships", SelectGunships, "Improved Air Selection")
    ReUI.Actions.SelectionAction("Exclude/Include Air Combat from Selection", TogglePin, "Improved Air Selection")

end
