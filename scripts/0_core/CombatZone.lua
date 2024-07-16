--- **Core**
--
-- ===
--- The COMBAT_ZONE class
-- @type COMBAT_ZONE
-- ===
--
-- ### Author: **w3z315**
--
-- ===
--
-- @field #COMBAT_ZONE
COMBAT_ZONE = {
    ClassName = "COMBAT_ZONE",
    Zone = nil,
    Polygon = nil,
    Point = nil,
    MarkIds = {},
    LineMarkIds = {},
    Name = "",
    Coalition = -2,
    ZoneColor = { .35, .35, .35 },
    SpawnedGroups = {},
    CentroidArea = nil,
}

function COMBAT_ZONE:New(name, polygon, coalition_side)
    local self = BASE:Inherit(self, BASE:New())
    self.Name = name
    self.Polygon = polygon
    self:DrawMarkings(polygon:GetCoordinates(), { .35, .35, .35 })
    self.Zone = ZONE_POLYGON:NewFromPointsArray(name, polygon:GetPoints())
    self.Coalition = coalition_side or coalition.side.NEUTRAL
    self.Point = polygon:GetCentroid()
    self.CentroidArea = ZONE_RADIUS:New(self.Name .. "_CentroidZone", self.Point, 3000, true)
    return self
end

function COMBAT_ZONE:SetCoalition(coalitionSide)
    self.Coalition = coalitionSide
    if coalitionSide ~= coalition.side.NEUTRAL then
        --self:DestroyUnits()
        --self:SpawnUnits()
    end
    return self
end

function COMBAT_ZONE:SpawnUnits()
    for _, groupName in ipairs(WZ_CONFIG.groups.defensive) do
        -- Spawn units
        local countryId
        if self.Coalition == coalition.side.BLUE then
            countryId = country.id.USA
        else
            countryId = country.id.RUSSIA
        end
        local spawnedGroup = SPAWN:New(groupName):InitCoalition(self.Coalition):InitCountry(countryId):SpawnInZone(self.CentroidArea, true)
        table.insert(self.SpawnedGroups, spawnedGroup)
    end
    for _, staticName in ipairs(WZ_CONFIG.statics.defensive) do
        local countryId
        if self.Coalition == coalition.side.BLUE then
            countryId = country.id.USA
        else
            countryId = country.id.RUSSIA
        end
        local spawn = SPAWNSTATIC:NewFromStatic(staticName, countryId):InitNamePrefix(self.Name .. '_Statics')
        local spawnCoords = self.CentroidArea:GetRandomCoordinate():SetAltitude(1)
        table.insert(self.SpawnedGroups, spawn:SpawnFromCoordinate(spawnCoords, 0))
    end
end

function COMBAT_ZONE:DestroyUnits()
    for _, group in ipairs(self.SpawnedGroups) do
        group:Destroy()
    end
end

function COMBAT_ZONE:ClearMarkings()
    for _, markId in ipairs(self.MarkIds) do
        UTILS.RemoveMark(markId)
    end
end

function COMBAT_ZONE:ClearLineMarkings()
    for _, markId in ipairs(self.LineMarkIds) do
        UTILS.RemoveMark(markId)
    end
end

function COMBAT_ZONE:DrawMarkings(coordinates)
    table.add(self.MarkIds, coordinates[1]:MarkupToAllFreeForm(coordinates, -1, self.ZoneColor, 1, self.ZoneColor, .25, 2, true))
end

function COMBAT_ZONE:AddToMarkingList(markId)
    table.add(self.MarkIds, markId)
end

function COMBAT_ZONE:AddToLineMarkingList(markId)
    table.add(self.LineMarkIds, markId)
end

function COMBAT_ZONE:Update()
    -- Todo: Unit spawn bug, move initial zone Coalition outside here
    if #self.SpawnedGroups == 0 and self.Coalition ~= coalition.side.NEUTRAL then
        self:SpawnUnits()
    end

    if self.Coalition == coalition.side.BLUE then
        self.ZoneColor = { 0, 0, 1 }
    elseif self.Coalition == coalition.side.RED then
        self.ZoneColor = { 1, 0, 0 }
    end

    if isAirbaseInZone(self.Zone, coalition.side.BLUE) and self.Coalition ~= coalition.side.BLUE then
        self:SetCoalition(coalition.side.BLUE)
        self.ZoneColor = { 0, 0, 1 }
    elseif isAirbaseInZone(self.Zone, coalition.side.RED) and self.Coalition ~= coalition.side.RED then
        self:SetCoalition(coalition.side.RED)
        self.ZoneColor = { 1, 0, 0 }
    end

    self:ClearMarkings()
    self:ClearLineMarkings()
    self:DrawMarkings(self.Polygon:GetCoordinates())

    if WZ_CONFIG.zone.markers.enable then
        -- Add a map marker
        local centroidPoints = self.Polygon:GetCentroid()
        local centroidCoords = COORDINATE:New(centroidPoints.x, 0, centroidPoints.y);
        centroidCoords:MarkToAll(self.Name, true)
    end

    return self
end

function COMBAT_ZONE:Destroy()
    self:DestroyUnits()
    self:ClearMarkings()
    self:ClearLineMarkings()
end