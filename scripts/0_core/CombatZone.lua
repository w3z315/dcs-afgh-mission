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
    MarkIds = {},
    Name = "",
    Coalition = -2,
}

function COMBAT_ZONE:New(name, polygon, coalition_side)
    local self = BASE:Inherit(self, BASE:New())
    self.Polygon = polygon
    self:DrawMarkings(polygon:GetCoordinates(), {.35,.35,.35})
    self.Zone = ZONE_POLYGON:NewFromPointsArray(name, polygon:GetPoints())
    self.Coalition = coalition_side or coalition.side.NEUTRAL
    return self
end

function COMBAT_ZONE:SetCoalition(coalition)
    self.Coalition = coalition
    return self
end

function COMBAT_ZONE:ClearMarkings()
    for _, markId in ipairs(self.MarkIds) do
        UTILS.RemoveMark(markId)
    end
end

function COMBAT_ZONE:DrawMarkings(coordinates, color)
    table.add(self.MarkIds, coordinates[1]:MarkupToAllFreeForm(coordinates, -1, color, 1, color, .25, 2, true))
end

function COMBAT_ZONE:Update()
    local zoneColor = {.35, .35, .35}
    self:SetCoalition(coalition.side.NEUTRAL)

    if isAirbaseInZone(self.Zone, coalition.side.BLUE) and self.Coalition ~= coalition.side.BLUE then
        self:SetCoalition(coalition.side.BLUE)
        zoneColor = {0, 0, 1}
    elseif isAirbaseInZone(self.Zone, coalition.side.RED) and self.Coalition ~= coalition.side.RED then
        self:SetCoalition(coalition.side.RED)
        zoneColor = { 1, 0, 0 }
    end

    self:ClearMarkings()
    self:DrawMarkings(self.Polygon:GetCoordinates(), zoneColor)


    if WZ_CONFIG.zone.markers.enable then
        -- Add a map marker
        local centroidPoints = self.Polygon:GetCentroid()
        local centroidCoords = COORDINATE:New(centroidPoints.x, 0, centroidPoints.y);
        centroidCoords:MarkToAll(self.Name, true)
    end
    return self
end