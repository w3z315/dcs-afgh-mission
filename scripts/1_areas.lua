-- Define the main zone
local zone_name = "Zone_Polygon_Area"
local mainZone = POLYGON:FindOnMap(zone_name)

local minX, minY, maxX, maxY
-- Get the min/max coordinates for bounds
local bounds = mainZone:GetBoundingBox()

local polygons = {}
WZ_CONFIG = WZ_CONFIG or {}
WZ_zoneNames = {}
WZ_triggerZones = {}

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

    if WZ_CONFIG.zone.markers.enable then
        -- Add a map marker
        local centroidPoints = zonePolygon:GetCentroid()
        local centroidCoords = COORDINATE:New(centroidPoints.x, 0, centroidPoints.y);
        centroidCoords:MarkToAll(zoneName, true)
    end

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
        table.add(WZ_zoneNames, zoneName)
        local polygon = createHexagon(centerX, centerY, zoneName, yOffset, xOffset)
        if polygon then
            table.insert(polygons, { [zoneName] = polygon })

            local polyCoords = polygon:GetCoordinates()
            local z = 1

            -- Draw polygons
            for _, coords in pairs(polyCoords) do
                local endPoint = polyCoords[z % #polyCoords + 1]
                coords:LineToAll(endPoint, -1, { .35, .35, .35 }, 1, 2, true)
                z = z + 1
            end

            local triggerZone = ZONE_POLYGON:NewFromPointsArray(zoneName, polygon:GetPoints())
            table.add(WZ_triggerZones, { [zoneName] = triggerZone })
            -- triggerZone:Scan({Object.Category.UNIT},{Unit.Category.AIRPLANE, Unit.Category.HELICOPTER})

        end
    end
end

if WZ_CONFIG.debug then
    MESSAGE:New(string.format("Total amount of zones: %d", #WZ_triggerZones)):ToAll()
end