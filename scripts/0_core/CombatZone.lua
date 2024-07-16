---@class COMBAT_ZONE : BASE
---@field protected ClassName string ClassName for base
---@field Zone ZONE_POLYGON The polygon zone of the combat zone
---@field Polygon POLYGON The polygon defining the combat zone
---@field Point POINT The central point of the combat zone
---@field MarkIds table<number> List of mark IDs
---@field LineMarkIds table<number> List of line mark IDs
---@field Name string Name of the combat zone
---@field Coalition number Coalition side of the combat zone
---@field ZoneColor table<number> RGB color of the zone
---@field SpawnedGroups table<GROUP> List of spawned groups in the combat zone
---@field CentroidArea ZONE_RADIUS The centroid area zone
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

--- Creates a new instance of the COMBAT_ZONE class
-- @param name string The name of the combat zone
-- @param polygon POLYGON The polygon defining the zone
-- @param coalition_side number The coalition side for the zone
-- @return COMBAT_ZONE A new instance of COMBAT_ZONE
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

function COMBAT_ZONE:IsBlueSide()
    return self.Coalition == coalition.side.BLUE
end

function COMBAT_ZONE:IsRedSide()
    return self.Coalition == coalition.side.RED
end

function COMBAT_ZONE:IsNeutral()
    return self.Coalition == coalition.side.NEUTRAL
end

--- Sets the coalition side for the combat zone
-- @param coalitionSide number The coalition side to set
-- @return COMBAT_ZONE The instance of COMBAT_ZONE
function COMBAT_ZONE:SetCoalition(coalitionSide)
    self.Coalition = coalitionSide
    if coalitionSide ~= coalition.side.NEUTRAL then
        --self:DestroyUnits()
        --self:SpawnUnits()
    end
    return self
end

--- Spawns units in the combat zone
function COMBAT_ZONE:SpawnUnits()
    for _, groupName in ipairs(WZ_CONFIG.groups.defensive) do
        local countryId = (self.Coalition == coalition.side.BLUE) and country.id.USA or country.id.RUSSIA
        local spawnedGroup = SPAWN:New(groupName):InitCoalition(self.Coalition):InitCountry(countryId):SpawnInZone(self.CentroidArea, true)
        table.insert(self.SpawnedGroups, spawnedGroup)
    end
    for _, staticName in ipairs(WZ_CONFIG.statics.defensive) do
        local countryId = (self.Coalition == coalition.side.BLUE) and country.id.USA or country.id.RUSSIA
        local spawn = SPAWNSTATIC:NewFromStatic(staticName, countryId):InitNamePrefix(self.Name .. '_Statics')
        local spawnCoords = self.CentroidArea:GetRandomCoordinate():SetAltitude(1)
        table.insert(self.SpawnedGroups, spawn:SpawnFromCoordinate(spawnCoords, 0))
    end
end

--- Destroys all units in the combat zone
function COMBAT_ZONE:DestroyUnits()
    for _, group in ipairs(self.SpawnedGroups) do
        group:Destroy()
    end
end

--- Clears all markings in the combat zone
function COMBAT_ZONE:ClearMarkings()
    for _, markId in ipairs(self.MarkIds) do
        UTILS.RemoveMark(markId)
    end
end

--- Clears all line markings in the combat zone
function COMBAT_ZONE:ClearLineMarkings()
    for _, markId in ipairs(self.LineMarkIds) do
        UTILS.RemoveMark(markId)
    end
end

--- Draws markings on the combat zone
-- @param coordinates table Coordinates for the markings
function COMBAT_ZONE:DrawMarkings(coordinates)
    table.add(self.MarkIds, coordinates[1]:MarkupToAllFreeForm(coordinates, -1, self.ZoneColor, 1, self.ZoneColor, .25, 2, true))
end

--- Adds a mark ID to the marking list
-- @param markId number The mark ID to add
function COMBAT_ZONE:AddToMarkingList(markId)
    table.add(self.MarkIds, markId)
end

--- Adds a mark ID to the line marking list
-- @param markId number The mark ID to add
function COMBAT_ZONE:AddToLineMarkingList(markId)
    table.add(self.LineMarkIds, markId)
end

--- Updates the combat zone
-- @return COMBAT_ZONE The updated instance of COMBAT_ZONE
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
        local centroidPoints = self.Polygon:GetCentroid()
        local centroidCoords = COORDINATE:New(centroidPoints.x, 0, centroidPoints.y)
        centroidCoords:MarkToAll(self.Name, true)
    end

    return self
end

--- Destroys the combat zone
function COMBAT_ZONE:Destroy()
    self:DestroyUnits()
    self:ClearMarkings()
    self:ClearLineMarkings()
end
