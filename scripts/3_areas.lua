WZ_CONFIG = WZ_CONFIG or {}
WZ_COMBAT_ZONES = {
    blue = {},
    red = {},
    neutral = {}
}

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
    -- Debugging messages for the main zone bounds and center
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
                table.add(WZ_COMBAT_ZONES.blue, combatZone)
            elseif combatZone.Coalition == coalition.side.RED then
                table.add(WZ_COMBAT_ZONES.red, combatZone)
            elseif combatZone.Coalition == coalition.side.NEUTRAL then
                table.add(WZ_COMBAT_ZONES.neutral, combatZone)
            end
        end
    end
end

if WZ_CONFIG.debug then
    MESSAGE:New(string.format("Total amount of blue zones: %d", #WZ_COMBAT_ZONES.blue), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of red zones: %d", #WZ_COMBAT_ZONES.red), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of neutral: %d", #WZ_COMBAT_ZONES.neutral), 25, "DEBUG"):ToAll()
end