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
