function isAirbaseInZone(zone, coalition)
    local airbases = AIRBASE.GetAllAirbases(coalition)

    -- Iterate over all airbases to check if any are within the zone
    for _, airbase in ipairs(airbases) do
        local airbaseZone = airbase:GetZone()
        if zone:IsPointVec2InZone(airbaseZone:GetCoordinate()) then
            return true
        end
    end

    return false
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