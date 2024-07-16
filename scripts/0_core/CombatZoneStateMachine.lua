---@class COMBAT_ZONE_STATE_MACHINE
---@field ClassName string
---@field CombatZones table<table<COMBAT_ZONE>>
---@field SpawnedGroups table
---@field GameEnded boolean
---@field __CombatZoneCoalitionMap table<string, string>
---@field __GameUpdateScheduler number
---@field __SubZoneRadius number
---@field __DrawnLines table<string, boolean>
COMBAT_ZONE_STATE_MACHINE = {
    ClassName = "COMBAT_ZONE_STATE_MACHINE",
    CombatZones = {
        blue = {},
        red = {},
        neutral = {},
    },
    SpawnedGroups = {},
    GameEnded = false,
    MainZone = {
        minX = 0,
        maxX = 0,
        minY = 0,
        maxY = 0,
        centerX = 0,
        centerY = 0,
        width = 0,
        height = 0,
    },
    __CombatZoneCoalitionMap = {},
    __GameUpdateScheduler = nil,
    __SubZoneRadius = nil,
    __DrawnLines = {},
}

--- Gets a new instance
--- @return self
function COMBAT_ZONE_STATE_MACHINE:New()
    local self = BASE:Inherit(self, BASE:New())
    return self
end

--- Creates a hexagon polygon
--- @param centerX number The x center coordinate
--- @param centerY number The y center coordinate
--- @param verticalOffset number Amount of y offset
--- @param horizontalOffset number Amount of x offset
function COMBAT_ZONE_STATE_MACHINE:CreateHexagon(centerX, centerY, verticalOffset, horizontalOffset)
    local points = {}
    for i = 0, 5 do
        local angle = (math.pi / 3) * i - (math.pi / 6)
        local x = centerX + self.__SubZoneRadius * math.cos(angle) + verticalOffset
        local y = centerY + self.__SubZoneRadius * math.sin(angle) + horizontalOffset
        table.insert(points, { x = x, y = y })
    end
    return POLYGON:New(unpack(points))
end

function COMBAT_ZONE_STATE_MACHINE:ProcessZonesForCoalition(coalitionSide, allZones)
    local filteredZones = filterTable(allZones, function(combatZone)
        return combatZone.Coalition == coalitionSide and combatZone
    end)

    for _, combatZone in ipairs(filteredZones) do
        local targetPoint = combatZone
        local adjacentPoints = findAdjacentPoints(allZones, targetPoint, WZ_CONFIG.zone.lineMaxDistance)

        local neutralColor = { .35, .35, .35 }
        local sameCoalitionColor = coalitionSide == coalition.side.BLUE and { 0, 0, 1 } or { 1, 0, 0 }
        local oppositeCoalitionColor = { 1, 1, 0 }
        local drawnOppositeLine = false

        for _, adjPoint in ipairs(adjacentPoints) do
            local lineColor = nil
            local lineStyle, lineAlpha = 2, .3

            if adjPoint.Coalition == coalition.side.NEUTRAL then
                lineColor = neutralColor
            elseif adjPoint.Coalition == targetPoint.Coalition then
                lineColor = sameCoalitionColor
            elseif not drawnOppositeLine then
                lineColor = oppositeCoalitionColor
                lineAlpha = 1
                lineStyle = 1
                drawnOppositeLine = true
            end

            if lineColor then
                local lineKey1 = targetPoint.Point.x .. "," .. targetPoint.Point.y .. "->" .. adjPoint.Point.x .. "," .. adjPoint.Point.y
                local lineKey2 = adjPoint.Point.x .. "," .. adjPoint.Point.y .. "->" .. targetPoint.Point.x .. "," .. targetPoint.Point.y

                if not self.__DrawnLines[lineKey1] and not self.__DrawnLines[lineKey2] then
                    local markId = COORDINATE:NewFromVec2(targetPoint.Point, 0):LineToAll(COORDINATE:NewFromVec2(adjPoint.Point, 0), -1, lineColor, lineAlpha, lineStyle, true)
                    combatZone:AddToLineMarkingList(markId)
                    self.__DrawnLines[lineKey1] = true
                    self.__DrawnLines[lineKey2] = true
                end
            end
        end
    end
end


--- Processes all combat zones
--- @param subdivisions number The amount of subdivision to create
function COMBAT_ZONE_STATE_MACHINE:ProcessCombatZones(subdivisions)
    for i = 0, subdivisions - 1 do
        for j = 0, subdivisions - 1 do
            local offsetX = i * (self.__SubZoneRadius * 2)
            local offsetY = j * (self.__SubZoneRadius * math.sqrt(3.8))
            if j % 2 == 1 then
                offsetX = offsetX + (self.__SubZoneRadius * 0.75)
            end
            local centerX = self.MainZone.minX + offsetX + self.__SubZoneRadius
            local centerY = self.MainZone.minY + offsetY + self.__SubZoneRadius
            local zoneName = string.format(WZ_CONFIG.zone.markers.textFormat, i + 1, j + 1)
            local polygon = self:CreateHexagon(centerX, centerY, WZ_CONFIG.zone.yOffset, WZ_CONFIG.zone.xOffset)
            if polygon then
                local combatZone = COMBAT_ZONE:New(zoneName, polygon):Update()
                if combatZone.Coalition == coalition.side.BLUE then
                    table.insert(self.CombatZones.blue, combatZone)
                elseif combatZone.Coalition == coalition.side.RED then
                    table.insert(self.CombatZones.red, combatZone)
                elseif combatZone.Coalition == coalition.side.NEUTRAL then
                    table.insert(self.CombatZones.neutral, combatZone)
                end
            end
        end
    end
end

function COMBAT_ZONE_STATE_MACHINE:GetWinner()
    local blueCount, redCount = #self.CombatZones.blue, #self.CombatZones.red
    if redCount == 0 then
        return coalition.side.BLUE
    elseif blueCount == 0 then
        return coalition.side.RED
    end
    return coalition.side.NEUTRAL
end

function COMBAT_ZONE_STATE_MACHINE:__CheckForWinners()
    local winner = self:GetWinner()
    if winner ~= coalition.side.NEUTRAL then
        if winner == coalition.side.BLUE then
            MESSAGE:New(string.format("BLUE HAS WON!\n\nCongratulations to the brave pilots of the BLUE team!\nZones captured: %d", self:GetZoneCount("blue")), 30, "MISSION ENDED", true):ToAll()
            USERSOUND:New("blue_won.ogg"):ToAll()
        elseif winner == coalition.side.RED then
            MESSAGE:New(string.format("RED HAS WON!\n\nHail to the victorious RED team!\nZones captured: %d", self:GetZoneCount("red")), 30, "MISSION ENDED", true):ToAll()
            USERSOUND:New("red_won.ogg"):ToAll()
        end
        if WZ_CONFIG.gameplay.restartAfterMissionEnds then
            MESSAGE:New(string.format("MISSION WILL RESTART IN %d SECONDS", WZ_CONFIG.gameplay.restartAfterSeconds), WZ_CONFIG.gameplay.restartAfterSeconds, "NOTICE"):ToAll()
            USERFLAG:New("restartMission"):Set(1, WZ_CONFIG.gameplay.restartAfterSeconds)
        end
        self.GameEnded = true
        return true
    end
    return false
end

--- Check if a combat zone coalition has changed
--- @param combatZone COMBAT_ZONE The combat zone to check
function COMBAT_ZONE_STATE_MACHINE:CombatZoneCoalitionChanged(combatZone)
    if not table.contains_key(self.__CombatZoneCoalitionMap, combatZone.Name) then
        table.insert(self.__CombatZoneCoalitionMap, {[combatZone.Name] = combatZone.Coalition})
        return true
    end

    if self.__CombatZoneCoalitionMap[combatZone.Name] ~= combatZone.Coalition then
        return true
    end

    return false
end

function COMBAT_ZONE_STATE_MACHINE:UpdateAllZones()
    if WZ_CONFIG.debug then
        MESSAGE:New("Updating", 2, "DEBUG"):ToAll()
    end
    if self:__CheckForWinners() and self.GameEnded then
        return
    end

    local allZones = combineTables(self.CombatZones)
    self.__DrawnLines = {}
    for _, combatZone in ipairs(allZones) do
        combatZone:Update()
        if combatZone:ShouldSpawnGroups() then
            if self:CombatZoneCoalitionChanged(combatZone) then
                table.insert(self.SpawnedGroups, combatZone:SpawnGroups())
                self.__CombatZoneCoalitionMap[combatZone.Name] = combatZone.Coalition
            end
        end
    end
    self:ProcessZonesForCoalition(coalition.side.RED, allZones)
    self:ProcessZonesForCoalition(coalition.side.BLUE, allZones)
    if WZ_CONFIG.debug then
        MESSAGE:New("Updated", 2, "DEBUG"):ToAll()
    end
end

function COMBAT_ZONE_STATE_MACHINE:GetWinningSide()
    if self:GetZoneCount("blue") > self:GetZoneCount("red") then
        return coalition.side.BLUE
    elseif self:GetZoneCount("blue") < self:GetZoneCount("red") then
        return coalition.SIDE.RED
    end
    return coalition.side.NEUTRAL
end

function COMBAT_ZONE_STATE_MACHINE:UpdateAdjacentZones()
    if self.GameEnded then
        return
    end

    local addedZonesForBlueSide, addedZonesForRedSide = 0, 0
    local allZones = shuffleTable(combineTables(self.CombatZones))
    local winningSide = self:GetWinningSide()

    for _, combatZone in ipairs(allZones) do
        if combatZone.Coalition ~= coalition.side.NEUTRAL then
            local adjacentPoints = findAdjacentPoints(allZones, combatZone, WZ_CONFIG.zone.lineMaxDistance)
            for _, adjPoint in ipairs(adjacentPoints) do
                if adjPoint.Coalition == coalition.side.NEUTRAL then
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

--- Start the CombatStateMachine, generate Zones and start the round
--- @param mapZone ZONE
function COMBAT_ZONE_STATE_MACHINE:Begin(mapZone)
    -- Generate CombatZones
    -- Get the min/max coordinates for bounds
    local bounds = mapZone:GetBoundingBox()

    -- Calculate the center and size of the main zone
    self.MainZone.minX = bounds[1].x
    self.MainZone.maxX = bounds[2].x
    self.MainZone.minY = bounds[2].y
    self.MainZone.maxY = bounds[4].y
    self.MainZone.centerX = (self.MainZone.minX + self.MainZone.maxX) / 2
    self.MainZone.centerY = (self.MainZone.minY + self.MainZone.maxY) / 2
    self.MainZone.width = self.MainZone.maxX - self.MainZone.minX
    self.MainZone.height = self.MainZone.maxY - self.MainZone.minY

    if WZ_CONFIG.debug then
        MESSAGE:New(string.format("Main Zone Bounds: minX = %f, maxX = %f, minY = %f, maxY = %f", self.MainZone.minX, self.MainZone.maxX, self.MainZone.minY, self.MainZone.maxY), 25, "DEBUG"):ToAll()
        MESSAGE:New(string.format("Main Zone Center: x = %f, y = %f", self.MainZone.centerX, self.MainZone.centerY), 25, "DEBUG"):ToAll()
    end

    -- Define the number of subdivisions (x * x grid)
    local subdivisions = WZ_CONFIG.zone.subdivisions

    -- Calculate the size of each subdivided zone (hexagon radius)
    self.__SubZoneRadius = (math.min(self.MainZone.width, self.MainZone.height) - 0 * (subdivisions - 1)) / subdivisions / 2

    self:ProcessCombatZones(subdivisions)

    self.__GameUpdateScheduler = SCHEDULER:New(self, function(stateMachine)
        stateMachine:UpdateAllZones()
    end, { self }, 0, WZ_CONFIG.gameplay.updateZonesEvery)
end

function COMBAT_ZONE_STATE_MACHINE:GetZoneCount(coalitionSide)
    return #self.CombatZones[coalitionSide]
end

function COMBAT_ZONE_STATE_MACHINE:Stop()
    if self.__GameUpdateScheduler ~= nil then
        SCHEDULER:Stop(self.__GameUpdateScheduler)
    end
end