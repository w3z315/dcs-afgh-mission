WZ_CONFIG = WZ_CONFIG or {}
WZ_COMBAT_ZONES = {
    blue = {},
    red = {},
    neutral = {}
}
WZ_LINE_AND_ZONE_MARKINGS = {}
WZ_GAME_ENDED = false

-- Define the main zone
local mainZone = POLYGON:FindOnMap(WZ_CONFIG.zone.name)

local minX, minY, maxX, maxY
-- Get the min/max coordinates for bounds
local bounds = mainZone:GetBoundingBox()

minX = bounds[1].x
maxX = bounds[2].x
minY = bounds[2].y
maxY = bounds[4].y

-- Calculate the center and size of the main zone
local mainZoneCenterX = (minX + maxX) / 2
local mainZoneCenterY = (minY + maxY) / 2
local mainZoneWidth = maxX - minX
local mainZoneHeight = maxY - minY

if WZ_CONFIG.debug then
    MESSAGE:New(string.format("Main Zone Bounds: minX = %f, maxX = %f, minY = %f, maxY = %f", minX, maxX, minY, maxY), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Main Zone Center: x = %f, y = %f", mainZoneCenterX, mainZoneCenterY), 25, "DEBUG"):ToAll()
end

-- Define the number of subdivisions (x * x grid)
local subdivisions = WZ_CONFIG.zone.subdivisions

-- Calculate the size of each subdivided zone (hexagon radius)
local subZoneRadius = (math.min(mainZoneWidth, mainZoneHeight) - 0 * (subdivisions - 1)) / subdivisions / 2

-- Define x and y offsets
local yOffset = WZ_CONFIG.zone.yOffset
local xOffset = WZ_CONFIG.zone.xOffset

-- Helper function to create a new hexagon zone and draw on the map
local function createHexagon(centerX, centerY, zoneName, verticalOffset, horizontalOffset)
    local points = {}

    -- Calculate the coordinates of the corners of the hexagon
    for i = 0, 5 do
        local angle = (math.pi / 3) * i - (math.pi / 6) -- Rotating 90 degrees (π/2 radians) from the default orientation
        local x = centerX + subZoneRadius * math.cos(angle) + verticalOffset
        local y = centerY + subZoneRadius * math.sin(angle) + horizontalOffset
        table.insert(points, { x = x, y = y })
    end

    -- Create the polygon zone
    local zonePolygon = POLYGON:New(unpack(points))

    return zonePolygon
end

local function processZonesForCoalition(coalitionSide, allZones)
    local filteredZones = filterTable(allZones, function(combatZone)
        if combatZone.Coalition == coalitionSide then
            return combatZone
        end
    end)

    for _, combatZone in ipairs(filteredZones) do
        local targetPoint = combatZone
        local adjacentPoints = findAdjacentPoints(allZones, targetPoint, WZ_CONFIG.zone.lineMaxDistance)
        local lineColor = coalitionSide == coalition.side.BLUE and { 0, 0, 1 } or { 1, 0, 0 }

        for _, adjPoint in ipairs(adjacentPoints) do
            local lineStyle, lineAlpha
            lineAlpha = .3
            if adjPoint.Coalition == targetPoint.Coalition then
                lineStyle = 2 -- Solid line
            elseif (adjPoint.Coalition == coalition.side.BLUE and targetPoint.Coalition == coalition.side.RED) or
                    (adjPoint.Coalition == coalition.side.RED and targetPoint.Coalition == coalition.side.BLUE) then
                lineStyle = 1 -- Dashed line
                lineColor = { 1, 1, 0 }
            else
                lineStyle = 5 -- Long dashes
            end

            local markId = COORDINATE:NewFromVec2(targetPoint.Point, 0):LineToAll(COORDINATE:NewFromVec2(adjPoint.Point, 0), -1, lineColor, lineAlpha, lineStyle, true)
            combatZone:AddToLineMarkingList(markId)
        end
    end
end

local function processCombatZones()
    WZ_COMBAT_ZONES = { blue = {}, red = {}, neutral = {} }
    -- Loop to create and place markers and drawings for each subdivided zone
    for i = 0, subdivisions - 1 do
        for j = 0, subdivisions - 1 do
            -- Calculate the center of the subdivided zone
            local offsetX = i * (subZoneRadius * 2)
            local offsetY = j * (subZoneRadius * math.sqrt(3.8))

            -- Adjust the x coordinate for every second row to create a hexagonal grid
            if j % 2 == 1 then
                offsetX = offsetX + (subZoneRadius * 0.75)
            end

            local centerX = minX + offsetX + subZoneRadius
            local centerY = minY + offsetY + subZoneRadius

            -- Create the sub-zone, place a marker, and draw on the map
            local zoneName = string.format(WZ_CONFIG.zone.markers.textFormat, i + 1, j + 1)
            local polygon = createHexagon(centerX, centerY, zoneName, yOffset, xOffset)
            if polygon then
                local combatZone = COMBAT_ZONE:New(zoneName, polygon):Update()

                if combatZone.Coalition == coalition.side.BLUE then
                    table.insert(WZ_COMBAT_ZONES.blue, combatZone)
                elseif combatZone.Coalition == coalition.side.RED then
                    table.insert(WZ_COMBAT_ZONES.red, combatZone)
                elseif combatZone.Coalition == coalition.side.NEUTRAL then
                    table.insert(WZ_COMBAT_ZONES.neutral, combatZone)
                end
            end
        end
    end
end

local function getWinner()
    local blueCount = #WZ_COMBAT_ZONES.blue
    local redCount = #WZ_COMBAT_ZONES.red
    if redCount == 0 then
        return coalition.side.BLUE
    elseif blueCount == 0 then
        return coalition.side.RED
    end
    return coalition.side.NEUTRAL
end

local function updateAllZones()
    if WZ_GAME_ENDED then
        return
    end


    local winner = getWinner()
    if winner ~= coalition.side.NEUTRAL then
        if winner == coalition.side.BLUE then
            local messageBlue = [[
BLUE HAS WON!

Congratulations to the brave pilots of the BLUE team!
Zones captured: %d
]]
            MESSAGE:New(string.format(messageBlue, #WZ_COMBAT_ZONES.blue), 30, "MISSION ENDED", true):ToAll()
            USERSOUND:New("blue_won.ogg"):ToAll()
        elseif winner == coalition.side.RED then
            local messageRed = [[
RED HAS WON!

Hail to the victorious RED team!
Zones captured: %d
]]
            MESSAGE:New(string.format(messageRed, #WZ_COMBAT_ZONES.red), 30, "MISSION ENDED", true):ToAll()
            USERSOUND:New("red_won.ogg"):ToAll()
        end
        if WZ_CONFIG.gameplay.restartAfterMissionEnds then
            MESSAGE:New(string.format("MISSION WILL RESTART IN %d SECONDS", WZ_CONFIG.gameplay.restartAfterSeconds), WZ_CONFIG.gameplay.restartAfterSeconds, "NOTICE"):ToAll()
            USERFLAG:New("restartMission"):Set(1, WZ_CONFIG.gameplay.restartAfterSeconds)
        end
        WZ_GAME_ENDED = true
    else

        if WZ_CONFIG.debug then
            MESSAGE:New("Updated", 2, "DEBUG"):ToAll()
        end

        local allZones = combineTables(WZ_COMBAT_ZONES)
        for _, combatZone in ipairs(allZones) do
            combatZone:ClearLineMarkings()
        end

        for _, combatZone in ipairs(allZones) do
            combatZone:Update()
        end

        -- Run processZonesForCoalition for BLUE and RED coalitions
        processZonesForCoalition(coalition.side.RED, allZones)
        processZonesForCoalition(coalition.side.BLUE, allZones)

    end

end

-- Function to get the coalition with fewer zones
local function getWinningSide()
    local blueCount = #WZ_COMBAT_ZONES.blue
    local redCount = #WZ_COMBAT_ZONES.red
    if blueCount > redCount then
        return coalition.side.BLUE
    else
        return coalition.side.RED
    end
end

local function changeAdjacentZonesCoalition()
    if WZ_GAME_ENDED then
        return
    end
    local addedZonesForBlueSide = 0
    local addedZonesForRedSide = 0
    local allZones = shuffleTable(combineTables(WZ_COMBAT_ZONES))
    local winningSide = getWinningSide()

    for _, combatZone in ipairs(allZones) do
        if combatZone.Coalition ~= coalition.side.NEUTRAL then
            local adjacentPoints = findAdjacentPoints(allZones, combatZone, WZ_CONFIG.zone.lineMaxDistance)
            for _, adjPoint in ipairs(adjacentPoints) do
                if adjPoint.Coalition == coalition.side.NEUTRAL then
                    -- Apply a reduced probability if the current zone's coalition is the winning side
                    local probability = (combatZone.Coalition == winningSide) and WZ_CONFIG.gameplay.winningSideProbability or 1.0
                    if math.random() <= probability then
                        if combatZone.Coalition == coalition.side.BLUE then
                            addedZonesForBlueSide = addedZonesForBlueSide + 1
                        elseif combatZone.Coalition == coalition.side.RED then
                            addedZonesForRedSide = addedZonesForRedSide + 1
                        end

                        adjPoint:SetCoalition(combatZone.Coalition)
                        adjPoint:Update()
                    end
                end
            end
        end
    end

    if addedZonesForRedSide > 0 or addedZonesForBlueSide > 0 then
        local messageBlue = string.format("Our ground units have captured %d new zone(s) for the Blue Side. Enemy ground forces have secured %d new zone(s) for the Red Side.", addedZonesForBlueSide, addedZonesForRedSide)
        local messageRed = string.format("Enemy ground forces have secured %d new zone(s) for the Red Side. Our ground units have captured %d new zone(s) for the Blue Side.", addedZonesForRedSide, addedZonesForBlueSide)

        MESSAGE:New(messageBlue, 30, "SITREP"):ToBlue()
        MESSAGE:New(messageRed, 30, "SITREP"):ToRed()

        if WZ_CONFIG.debug then
            MESSAGE:New(messageBlue, 30, "SITREP"):ToAll()
            MESSAGE:New(messageRed, 30, "SITREP"):ToAll()
        end
    end
end

-- Run processCombatZones once
processCombatZones()

if WZ_CONFIG.gameplay.enableExpandingZones then
    MESSAGE:New(string.format("Expanding zones enabled! Expanding sides every %d seconds.", WZ_CONFIG.gameplay.expandZonesEvery), 30, "GAMEPLAY INFO"):ToAll()
    -- Schedule the change of adjacent zones coalition every 30 seconds
    SCHEDULER:New(nil, changeAdjacentZonesCoalition, {}, WZ_CONFIG.gameplay.expandZonesEvery, WZ_CONFIG.gameplay.expandZonesEvery)
end

-- Schedule the update of all zones every 3 seconds
SCHEDULER:New(nil, updateAllZones, {}, 0, WZ_CONFIG.gameplay.updateZonesEvery)

if WZ_CONFIG.debug then
    MESSAGE:New(string.format("Total amount of blue zones: %d", #WZ_COMBAT_ZONES.blue), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of red zones: %d", #WZ_COMBAT_ZONES.red), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of neutral: %d", #WZ_COMBAT_ZONES.neutral), 25, "DEBUG"):ToAll()
end
