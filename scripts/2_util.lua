function hasAnyAirbases(zone, coalition, airbaseCategory)
    local airbases = AIRBASE.GetAllAirbases(coalition, airbaseCategory)

    -- Iterate over all airbases to check if any are within the zone
    for _, airbase in ipairs(airbases) do
        local airbaseZone = airbase:GetZone()
        if airbaseZone ~= nil then
            if zone:IsCoordinateInZone(airbaseZone:GetCoordinate()) then
                return true
            end
        end
    end

    return false
end
function getAnyAirbases(zone, coalition, airbaseCategory)
    local airbases = AIRBASE.GetAllAirbases(coalition, airbaseCategory)
    local airbasesInZone = {}
    -- Iterate over all airbases to check if any are within the zone
    for _, airbase in ipairs(airbases) do
        local airbaseZone = workaroundAirbaseZone(airbase)
        if airbaseZone ~= nil then
            if zone:IsCoordinateInZone(airbaseZone:GetCoordinate()) then
                if WZ_CONFIG.debug then
                    MESSAGE:New(string.format("AIRBASE IN ZONE: %s", airbase.AirbaseName), 3, "DEBUG"):ToAll()
                end
                table.add(airbasesInZone, airbase)
            end
        else
            if WZ_CONFIG.debug then
                MESSAGE:New(string.format("AIRBASE HAS NO ZONE: %s", airbase.AirbaseName), 3, "DEBUG"):ToAll()
            end
        end
    end

    return airbasesInZone
end

function workaroundAirbaseZone(airbase)
    local airbaseZone = airbase:GetZone()
    if airbaseZone == nil then
        -- Check if airbase has VEC2
        local airbaseVec2 = airbase:GetVec2()

        -- Workaround for respawned airbases (they're missing the zones)
        if airbaseVec2 then
            if string.startswith(airbase.AirbaseName, "FARP-") then
                -- Most likely a FARP so this is another bug fix
                airbase.isShip = false
            end
            if airbase.isShip then
                local unit=UNIT:FindByName(airbase.AirbaseName)
                if unit then
                    airbaseZone = ZONE_UNIT:New(airbase.AirbaseName, unit, 2500)
                else
                    MESSAGE:New(string.format("AIRBASE UNIT %s NOT FOUND", airbase.AirbaseName), 3, "DEBUG"):ToAll()
                end
            else
                airbaseZone = ZONE_RADIUS:New(airbase.AirbaseName, airbaseVec2, 2500)
            end
        else
            UTILS.PrintTableToLog(airbase)
        end
    end
    return airbaseZone
end

-- Function to combine the tables
function combineTables(baseTable)
    local combined = {}

    for _, zone in pairs(baseTable) do
        for _, value in ipairs(zone) do
            table.insert(combined, value)
        end
    end

    return combined
end

function filterTable(tbl, callback)
    local filteredTable = {}
    for _, value in ipairs(tbl) do
        if callback(value) then
            table.insert(filteredTable, value)
        end
    end

    return filteredTable
end

function shuffleTable(t)
    local shuffled = {}
    local len = #t

    for i = len, 1, -1 do
        -- Get a random index between 1 and i
        local rand = math.random(i)

        -- Insert the element at the random index into the shuffled table
        table.insert(shuffled, t[rand])

        -- Remove the element from the original table to avoid duplicates
        table.remove(t, rand)
    end

    return shuffled
end

-- Array map equivalent
function mapTable(tbl, callback)
    local mappedTable = {}
    for _, value in ipairs(tbl) do
        table.insert(mappedTable, callback(value))
    end

    return mappedTable
end

function countTableEntries(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end


function getTimeLeftFromSeconds(seconds)
    local hours = string.format("%02d", math.floor(seconds / 3600))
    local minutes = string.format("%02d", math.floor((seconds % 3600) / 60))
    local secs = string.format("%02d", seconds % 60)

    return hours .. ":" .. minutes .. ":" .. secs
end