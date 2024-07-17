---@class COMBAT_ZONE_STATUS
COMBAT_ZONE_STATUS = {
    CAPTURED = {},
    CAPTURING = {},
    NEUTRAL = {},
}
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
    FirstSpawn = true,
    IsAirBase = false,
    Status = COMBAT_ZONE_STATUS.NEUTRAL,
    CanBeCaptured = false,
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

function COMBAT_ZONE:GetKeyName()
    return self.Name:gsub("%s+", ""):gsub("\-+", "")
end

--- Sets the coalition side for the combat zone
-- @param coalitionSide number The coalition side to set
-- @return COMBAT_ZONE The instance of COMBAT_ZONE
function COMBAT_ZONE:SetCoalition(coalitionSide)
    self.Coalition = coalitionSide
    self:UpdateAirbases()
    return self
end

--- Spawns units in the combat zone
--- @return table
function COMBAT_ZONE:SpawnGroups()
    for _, groupSettings in ipairs(WZ_CONFIG.groups.defensive) do
        local groupName = groupSettings.name
        local shouldSpawn = (math.random() <= groupSettings.probability)

        if groupSettings.alwaysPresentOnAirBase and self.IsAirBase then
            shouldSpawn = true
        end
        if shouldSpawn then
            local countryId = (self.Coalition == coalition.side.BLUE) and country.id.USA or country.id.RUSSIA
            local spawnedGroup = SPAWN:NewWithAlias(groupName, groupName .. "-" .. math.random(1, 10000))
                                      :InitCoalition(self.Coalition)
                                      :InitCountry(countryId)
                                      :OnSpawnGroup(function(group)
                local name = group:GetName()
                local u = group:GetFirstUnitAlive()
                env.info(name .. " has spawned  " .. tostring(group:GetID()) .. ' ... first unit: ' .. (u and u:GetID() or '<none>') .. ' / ' .. (u and u:GetName() or '?'))
            end)
                                      :SpawnInZone(self.CentroidArea, true)
            table.insert(self.SpawnedGroups, spawnedGroup)
        end
    end
    for _, staticSettings in ipairs(WZ_CONFIG.statics.defensive) do
        local staticName = staticSettings.name
        local shouldSpawn = (math.random() <= staticSettings.probability)

        if staticSettings.alwaysPresentOnAirBase and self.IsAirBase then
            shouldSpawn = true
        end

        if shouldSpawn then
            local countryId = (self.Coalition == coalition.side.BLUE) and country.id.USA or country.id.RUSSIA
            local spawn = SPAWNSTATIC:NewFromStatic(staticName, countryId):InitNamePrefix(self.Name .. '_Statics')
            local spawnCoords = self.CentroidArea:GetRandomCoordinate():SetAltitude(1)
            if staticSettings.isAirBase then
                -- It's a FARP we need to register it
                spawn:InitFARP()
            end
            table.insert(self.SpawnedGroups, spawn:SpawnFromCoordinate(spawnCoords, 0))
        end
    end
    if self.FirstSpawn and self:HasGroups() then
        if WZ_CONFIG.debug then
            MESSAGE:New("CombatZone spawned units for the first time.", 2, "DEBUG"):ToAll()
        end
        self.FirstSpawn = false
    end
    return self.SpawnedGroups
end

function COMBAT_ZONE:AnyUnitHasDifferentCoalition()
    return countTableEntries(filterTable(self.SpawnedGroups), function(group)
        return group:GetCoalition() ~= self.Coalition
    end) > 0
end

function COMBAT_ZONE:GetAirbasesInZone()
    local airbases = AIRBASE.GetAllAirbases()
    local combatZone = self
    return filterTable(airbases, function(airbase)
        return combatZone.Zone:IsPointVec2InZone(airbase:GetZone():GetCoordinate())
    end)
end

function COMBAT_ZONE:UpdateAirbases()
    for _, airbase in ipairs(self:GetAirbasesInZone()) do
        airbase:SetCoalition(self.Coalition)
    end
end

--- Destroys all units in the combat zone
function COMBAT_ZONE:DestroyGroups()
    for _, group in ipairs(self.SpawnedGroups) do
        group:Destroy()
    end
end

function COMBAT_ZONE:HasGroups()
    return countTableEntries(self.SpawnedGroups) > 0
end

function COMBAT_ZONE:IsBeingCaptured()
    return self.Status == COMBAT_ZONE_STATUS.CAPTURING
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

function COMBAT_ZONE:GetReadableStatus()
    if self.Status == COMBAT_ZONE_STATUS.CAPTURING then
        return "CAPTURING"
    elseif self.Status == COMBAT_ZONE_STATUS.CAPTURED then
        return "CAPTURED"
    end
    return "NEUTRAL"
end

function COMBAT_ZONE:SetStatus(combatZoneStatus)
    self.Status = combatZoneStatus

    if self.Status == COMBAT_ZONE_STATUS.NEUTRAL and not self:IsNeutral() then
        self.Status = COMBAT_ZONE_STATUS.CAPTURED
    end
    return self
end

--- Updates the combat zone
-- @return COMBAT_ZONE The updated instance of COMBAT_ZONE
function COMBAT_ZONE:Update()
    -- Set color based on coalition and status
    if self.Coalition == coalition.side.BLUE then
        self.ZoneColor = { 0, 0, 1 }
    elseif self.Coalition == coalition.side.RED then
        self.ZoneColor = { 1, 0, 0 }
    else
        self.ZoneColor = { 0.5, 0.5, 0.5 }
    end

    if WZ_CONFIG.debug then
        -- Debug message to confirm color and status change
        MESSAGE:New("Updating zone: " .. self.Name .. " with coalition: " .. tostring(self.Coalition) .. " and status: " .. self:GetReadableStatus(), 5, "DEBUG"):ToAll()
    end

    -- Update for airbase
    if isAirbaseInZone(self.Zone, coalition.side.BLUE) then
        self:SetCoalition(coalition.side.BLUE)
        self.ZoneColor = { 0, 0, 1 }
        self.IsAirBase = true
    elseif isAirbaseInZone(self.Zone, coalition.side.RED) then
        self:SetCoalition(coalition.side.RED)
        self.ZoneColor = { 1, 0, 0 }
        self.IsAirBase = true
    else
        self.IsAirBase = false
    end

    -- Clear old markings and draw new ones
    self:ClearMarkings()
    self:ClearLineMarkings()
    self:DrawMarkings(self.Polygon:GetCoordinates())

    -- Draw marker for zone status
    if WZ_CONFIG.zone.markers.enable then
        local centroidPoints = self.Polygon:GetCentroid()
        local offsetCoords = COORDINATE:New(centroidPoints.x + 20000, 0, centroidPoints.y - 15000)
        local markerText = self.Name
        local markerColor = self.ZoneColor
        local textColor = { 1, 1, 1 }

        if not self:IsNeutral() then
            if self:IsBlueSide() then
                markerText = markerText .. "\n\nUnder BLUE control"
            else
                markerText = markerText .. "\n\nUnder RED control"
            end
        end

        if WZ_CONFIG.zone.markers.enableCapturingStatus and self:IsBeingCaptured() then
            textColor = { 0, 0, 0 }
            markerColor = { 1, 1, 0 }
            markerText = self.Name .. "\n\nIS BEING CAPTURED"
        end

        table.insert(self.MarkIds, offsetCoords:TextToAll(markerText, -1, textColor, 1.0, markerColor, .8, 10, true))
    end
    return self
end

function COMBAT_ZONE:ShouldSpawnGroups()
    -- Has never spawned any groups but is not neutral
    if not self:IsBeingCaptured() then
        if self.FirstSpawn and not self:IsNeutral() then
            return true
        end
        -- Has no units but has coalition
        if not self.FirstSpawn and not self:IsNeutral() and not self:HasGroups() then
            return true
        end
    end

    return false
end

--- Destroys the combat zone
function COMBAT_ZONE:Destroy()
    self:DestroyGroups()
    self:ClearMarkings()
    self:ClearLineMarkings()
end
