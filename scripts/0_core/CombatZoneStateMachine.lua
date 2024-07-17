---@class COMBAT_ZONE_STATE_MACHINE
---@field ClassName string
---@field CombatZones table<table<COMBAT_ZONE>>
---@field SpawnedGroups table
---@field GameEnded boolean
---@field __CombatZoneCoalitionMap table<string, string>
---@field __GameUpdateScheduler number
---@field __ExpandingZonesScheduler number
---@field __ExpandingZoneTimerScheduler number
---@field __SubZoneRadius number
---@field __DrawnLines table<string, boolean>
COMBAT_ZONE_STATE_MACHINE = {
    ClassName = "COMBAT_ZONE_STATE_MACHINE",
    CombatZones = {
        blue = {},
        red = {},
        neutral = {},
    },
    CapturableCombatZones = {},
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
    HeadQuarters = {
        blue = nil,
        red = nil,
    },
    Missions = {},
    __CombatZoneCoalitionMap = {},
    __GameUpdateScheduler = nil,
    __ExpandingZonesScheduler = nil,
    __ExpandingZoneTimerScheduler = nil,
    __SubZoneRadius = nil,
    __DrawnLines = {},
    __TimerMarkerId = nil,
    __TimeLeftUntilNextExpandingZone = 0,
    __Clients = {},
}

--- Gets a new instance
--- @return self
function COMBAT_ZONE_STATE_MACHINE:New()
    local self = BASE:Inherit(self, BASE:New())
    self.__TimeLeftUntilNextExpandingZone = WZ_CONFIG.gameplay.expandZonesEvery
    self.__Clients = SET_CLIENT:New():FilterActive():FilterStart()
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

--- Checks if zone can be captured based on adjacent zones
--- @param targetZone COMBAT_ZONE
--- @param adjacentZones table<COMBAT_ZONE>
function COMBAT_ZONE_STATE_MACHINE:CanZoneBeCaptured(targetZone, adjacentZones)
    return countTableEntries(filterTable(adjacentZones, function(zone)
        return zone.Coalition ~= targetZone.Coalition
    end)) > 0
end

function COMBAT_ZONE_STATE_MACHINE:ProcessZonesForCoalition(coalitionSide, allZones)
    local filteredZones = filterTable(allZones, function(combatZone)
        return combatZone.Coalition == coalitionSide and combatZone
    end)

    for _, combatZone in ipairs(filteredZones) do
        local targetZone = combatZone
        local adjacentZones = findAdjacentZones(allZones, targetZone, WZ_CONFIG.zone.lineMaxDistance)

        -- Check if this point can be captured at all
        --if self:CanZoneBeCaptured(targetZone, adjacentZones) then
            local targetZoneKey = targetZone:GetKeyName()
            -- Enable ZoneCaptureCoalition
            local capturableZone
            if table.contains_key(self.CapturableCombatZones, targetZoneKey) then
                capturableZone = self.CapturableCombatZones[targetZoneKey]
                capturableZone.stateMachine = self
                capturableZone.targetZone = targetZone
            else
                if WZ_CONFIG.debug then
                    MESSAGE:New("UPDATING CAPTURABLE ZONES" , 5, "DEBUG"):ToAll()
                end
                self.CapturableCombatZones[targetZoneKey] = ZONE_CAPTURE_COALITION:New(targetZone.Zone, targetZone.Coalition, {Unit.Category.AIRPLANE, Unit.Category.HELICOPTER, Unit.Category.GROUND_UNIT})
                capturableZone = self.CapturableCombatZones[targetZoneKey]
                capturableZone.stateMachine = self
                capturableZone.targetZone = targetZone

                function capturableZone:OnEnterAttacked(from, event, to)
                    local Coalition = self:GetCoalition()
                    if WZ_CONFIG.debug then
                        MESSAGE:New("OnEnterAttacked: from: " .. from .. " to: " .. to .. " Coalition: " .. Coalition , 5, "DEBUG"):ToAll()
                    end
                    if from ~= to then
                        self.targetZone:SetStatus(COMBAT_ZONE_STATUS.CAPTURING)
                    end
                    self.targetZone:Update()
                end
                function capturableZone:OnEnterGuarded(from, event, to)
                    local Coalition = self:GetCoalition()
                    if WZ_CONFIG.debug then
                        MESSAGE:New("OnEnterGuarded: from: " .. from .. " to: " .. to .. " Coalition: " .. Coalition , 5, "DEBUG"):ToAll()
                    end
                    if from ~= to then
                        self.targetZone:SetStatus(COMBAT_ZONE_STATUS.CAPTURED)
                    end
                    self.targetZone:Update()
                end
                function capturableZone:OnEnterEmpty(from, event, to)
                    local Coalition = self:GetCoalition()
                    if WZ_CONFIG.debug then
                        MESSAGE:New("OnEnterEmpty: from: " .. from .. " to: " .. to .. " Coalition: " .. Coalition , 5, "DEBUG"):ToAll()
                    end

                    if from ~= to then
                        if Coalition ~= coalition.side.NEUTRAL then
                            self.targetZone:SetStatus(COMBAT_ZONE_STATUS.CAPTURED)
                        else
                            self.targetZone:SetStatus(COMBAT_ZONE_STATUS.NEUTRAL)
                        end
                    end
                    self.targetZone:Update()
                end
                function capturableZone:OnEnterCaptured(from, event, to)
                    local Coalition = self:GetCoalition()
                    if Coalition ~= self.targetZone.Coalition then
                        self.targetZone:SetCoalition(Coalition)
                        if WZ_CONFIG.debug then
                            MESSAGE:New("OnEnterCaptured: from: " .. from .. " to: " .. to .. " Coalition: " .. Coalition , 5, "DEBUG"):ToAll()
                        end

                        self.targetZone.SetStatus(COMBAT_ZONE_STATUS.CAPTURED)

                        if Coalition == coalition.side.BLUE then
                            self.stateMachine.HeadQuarters.red:MessageTypeToCoalition( string.format( "%s is captured by the USA, we lost it!", self:GetZoneName() ), MESSAGE.Type.Information )
                            self.stateMachine.HeadQuarters.blue:MessageTypeToCoalition( string.format( "We captured %s, Excellent job!", self:GetZoneName() ), MESSAGE.Type.Information )
                            table.insert(self.stateMachine.CombatZones.blue, self.targetZone)
                            self.stateMachine:RemoveZoneFromCoalitionTable(self.stateMachine.CombatZones.blue, self.targetZone)
                        elseif Coalition == coalition.side.RED then
                            self.stateMachine.HeadQuarters.blue:MessageTypeToCoalition( string.format( "%s is captured by Russia, we lost it!", self:GetZoneName() ), MESSAGE.Type.Information )
                            self.stateMachine.HeadQuarters.red:MessageTypeToCoalition( string.format( "We captured %s, Excellent job!", self:GetZoneName() ), MESSAGE.Type.Information )
                            table.insert(self.stateMachine.CombatZones.red, self.targetZone)
                            self.stateMachine:RemoveZoneFromCoalitionTable(self.stateMachine.CombatZones.red, self.targetZone)
                        else
                            -- Remove the adjPoint from the neutral table
                            self.stateMachine:RemoveZoneFromCoalitionTable(self.stateMachine.CombatZones.neutral, self.targetZone)
                        end
                        self.targetZone:Update()

                        self:__Guard( 30 )
                    end
                end

                capturableZone:Start(3, 15):Guard()
            end
        --end

        local neutralColor = { .35, .35, .35 }
        local sameCoalitionColor = coalitionSide == coalition.side.BLUE and { 0, 0, 1 } or { 1, 0, 0 }
        local oppositeCoalitionColor = { 1, 1, 0 }
        local drawnOppositeLine = false

        for _, adjZone in ipairs(adjacentZones) do
            local lineColor
            local lineStyle, lineAlpha = 2, .3

            if adjZone.Coalition == coalition.side.NEUTRAL then
                lineColor = neutralColor
            elseif adjZone.Coalition == targetZone.Coalition then
                lineColor = sameCoalitionColor
            elseif not drawnOppositeLine then
                lineColor = oppositeCoalitionColor
                lineAlpha = 1
                lineStyle = 1
                drawnOppositeLine = true
            end

            if lineColor then
                local lineKey1 = targetZone.Point.x .. "," .. targetZone.Point.y .. "->" .. adjZone.Point.x .. "," .. adjZone.Point.y
                local lineKey2 = adjZone.Point.x .. "," .. adjZone.Point.y .. "->" .. targetZone.Point.x .. "," .. targetZone.Point.y

                if not self.__DrawnLines[lineKey1] and not self.__DrawnLines[lineKey2] then
                    local markId = COORDINATE:NewFromVec2(targetZone.Point, 0):LineToAll(COORDINATE:NewFromVec2(adjZone.Point, 0), -1, lineColor, lineAlpha, lineStyle, true)
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
    local blueCount, redCount = countTableEntries(self.CombatZones.blue), countTableEntries(self.CombatZones.red)
    if redCount == 0 then
        return coalition.side.BLUE
    elseif blueCount == 0 then
        return coalition.side.RED
    end
    return coalition.side.NEUTRAL
end

function COMBAT_ZONE_STATE_MACHINE:HasNeutralZones()
    return #self.CombatZones.neutral > 0
end

function COMBAT_ZONE_STATE_MACHINE:__CheckForWinners()
    local winner = self:GetWinner()
    if winner ~= coalition.side.NEUTRAL then
        if winner == coalition.side.BLUE then
            MESSAGE:New(string.format(WZ_CONFIG.messages.win.blueMessage, self:GetZoneCount("blue")), 30, "MISSION ENDED", true):ToAll()
            USERSOUND:New("blue_won.ogg"):ToAll()
        elseif winner == coalition.side.RED then
            MESSAGE:New(string.format(WZ_CONFIG.messages.win.redMessage, self:GetZoneCount("red")), 30, "MISSION ENDED", true):ToAll()
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
        table.insert(self.__CombatZoneCoalitionMap, { [combatZone.Name] = combatZone.Coalition })
        return true
    end

    if self.__CombatZoneCoalitionMap[combatZone.Name] ~= combatZone.Coalition then
        return true
    end

    return false
end

function COMBAT_ZONE_STATE_MACHINE:UpdateAllZones(combatZoneChanged)
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
            if self:CombatZoneCoalitionChanged(combatZone) or combatZone.Name == combatZoneChanged then
                if combatZone:AnyUnitHasDifferentCoalition() then
                    combatZone:DestroyGroups()
                end
                table.insert(self.SpawnedGroups, combatZone:SpawnGroups())
                self.__CombatZoneCoalitionMap[combatZone.Name] = combatZone.Coalition
            end
        end
    end
    self:ProcessZonesForCoalition(coalition.side.RED, allZones)
    self:ProcessZonesForCoalition(coalition.side.BLUE, allZones)
    self:ProcessZonesForCoalition(coalition.side.NEUTRAL, allZones)
    if WZ_CONFIG.debug then
        MESSAGE:New("Updated", 2, "DEBUG"):ToAll()
        MESSAGE:New(string.format("Capturable combat zones: %d", countTableEntries(self.CapturableCombatZones)), 2, "DEBUG"):ToAll()
    end
end

function COMBAT_ZONE_STATE_MACHINE:GetWinningSide()
    if self:GetZoneCount("blue") > self:GetZoneCount("red") then
        return coalition.side.BLUE
    elseif self:GetZoneCount("blue") < self:GetZoneCount("red") then
        return coalition.side.RED
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
            local adjacentZones = findAdjacentZones(allZones, combatZone, WZ_CONFIG.zone.lineMaxDistance)
            for _, adjZone in ipairs(adjacentZones) do
                if adjZone.Coalition == coalition.side.NEUTRAL then
                    -- Increase the probability based on some factors
                    local probability = (combatZone.Coalition == winningSide) and WZ_CONFIG.gameplay.winningSideProbability or 0.8
                    -- Add a base chance to ensure some captures occur
                    probability = math.max(probability, 0.8)

                    if math.random() <= probability then
                        -- Update the coalition of the adjacent point
                        local newCoalition = combatZone.Coalition
                        adjZone:SetCoalition(newCoalition)
                        adjZone:Update()

                        -- Remove the adjPoint from the neutral table
                        self:RemoveZoneFromCoalitionTable(self.CombatZones.neutral, adjZone)

                        if newCoalition == coalition.side.BLUE then
                            addedZonesForBlueSide = addedZonesForBlueSide + 1
                            table.insert(self.CombatZones.blue, adjZone)
                            -- Remove from red table if it exists
                            self:RemoveZoneFromCoalitionTable(self.CombatZones.red, adjZone)
                        elseif newCoalition == coalition.side.RED then
                            addedZonesForRedSide = addedZonesForRedSide + 1
                            table.insert(self.CombatZones.red, adjZone)
                            -- Remove from blue table if it exists
                            self:RemoveZoneFromCoalitionTable(self.CombatZones.blue, adjZone)
                        end
                    end
                end
            end
        end
    end

    if addedZonesForRedSide > 0 or addedZonesForBlueSide > 0 then
        local messageBlue = string.format(WZ_CONFIG.messages.expandingZones.blueMessage, addedZonesForBlueSide, addedZonesForRedSide)
        local messageRed = string.format(WZ_CONFIG.messages.expandingZones.redMessage, addedZonesForRedSide, addedZonesForBlueSide)
        MESSAGE:New(messageBlue, 30, "SITREP"):ToBlue()
        MESSAGE:New(messageRed, 30, "SITREP"):ToRed()
        if WZ_CONFIG.debug then
            MESSAGE:New(messageBlue, 30, "SITREP"):ToAll()
            MESSAGE:New(messageRed, 30, "SITREP"):ToAll()
        end
    end
end

--- Removes a zone from a coalition table
--- @param coalitionTable table The coalition table (blue, red, or neutral)
--- @param zone COMBAT_ZONE The zone to remove
function COMBAT_ZONE_STATE_MACHINE:RemoveZoneFromCoalitionTable(coalitionTable, zone)
    for i = countTableEntries(coalitionTable), 1, -1 do
        if coalitionTable[i] == zone then
            table.remove(coalitionTable, i)
            break
        end
    end
end

-- Checks if clients need updates
function COMBAT_ZONE_STATE_MACHINE:UpdateClients()
    self.__Clients:ForEachClient(function(client)
        DATABASE:GetPlayers()
        if client:GetGroup() then
            local group = client:GetGroup()
            if client:GetPlayerName() then
                MESSAGE:New(client:GetPlayerName() .. ": " .. group:GetName(), 10):ToAll()
            else
                MESSAGE:New(tostring(client:IsAlive()) .. ": " .. group:GetName(), 10):ToAll()
            end
            local joinedPlayers = mapTable(DATABASE:GetPlayersJoined(), function(playerUnit)
                return playerUnit:GetPlayerName()
            end)
            if group:IsAlive() and not table.contains(joinedPlayers, client:GetPlayerName()) then
                MESSAGE:New(WZ_CONFIG.messages.missionIntro, 30, "BRIEFING"):ToClient(client)
                if WZ_CONFIG.audio.missionIntroSound then
                    USERSOUND:New(WZ_CONFIG.audio.missionIntroSoundFile):ToClient(client)
                end
            end
        end
    end)
end

--- Start the CombatStateMachine, generate Zones and start the round
--- @param mapZone ZONE
function COMBAT_ZONE_STATE_MACHINE:Begin(mapZone)
    -- Create headquarters
    self.HeadQuarters.red = COMMANDCENTER:New(
            GROUP:FindByName(WZ_CONFIG.statics.headQuarters.red.groupName),
            WZ_CONFIG.statics.headQuarters.red.prettyName
    )
    self.HeadQuarters.blue = COMMANDCENTER:New(
            GROUP:FindByName(WZ_CONFIG.statics.headQuarters.blue.groupName),
            WZ_CONFIG.statics.headQuarters.blue.prettyName
    )

    self.Missions.blue = MISSION:New(self.HeadQuarters.blue, "Weazel's zone fun", "Primary", WZ_CONFIG.messages.missionIntro, coalition.side.BLUE)
    self.Missions.red = MISSION:New(self.HeadQuarters.red, "Weazel's zone fun", "Primary", WZ_CONFIG.messages.missionIntro, coalition.side.RED)

    self.Missions.blue:Start()
    self.Missions.red:Start()

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
    self.__PlayerCheckScheduler = SCHEDULER:New(self, function(stateMachine)
        stateMachine:UpdateClients()
    end, { self }, 0, WZ_CONFIG.gameplay.updatePlayerStatusEvery)
    return self
end

function COMBAT_ZONE_STATE_MACHINE:DrawExpandingZoneTimer()
    local x = self.MainZone.maxX + 100000
    local y = self.MainZone.maxY - 6500
    local markerText = "Zones expanding in: " .. getTimeLeftFromSeconds(self.__TimeLeftUntilNextExpandingZone)
    self.__TimerMarkerId = COORDINATE:New(x, 0, y):TextToAll(markerText, -1, { 1, 1, 1 }, 1.0, { 1, 0, 0 }, 1, 20, true)
end

function COMBAT_ZONE_STATE_MACHINE:TickExpandingZoneTimerClock()
    self.__TimeLeftUntilNextExpandingZone = self.__TimeLeftUntilNextExpandingZone - 1
    if self.__TimeLeftUntilNextExpandingZone <= 0 then
        self.__TimeLeftUntilNextExpandingZone = WZ_CONFIG.gameplay.expandZonesEvery
    end
    self:ClearMarkers()
    self:DrawExpandingZoneTimer()
end

function COMBAT_ZONE_STATE_MACHINE:ClearMarkers()
    if self.__TimerMarkerId ~= nil then
        UTILS.RemoveMark(self.__TimerMarkerId)
    end
end

function COMBAT_ZONE_STATE_MACHINE:ClearCapturableCombatZones()
    for _, zoneCaptureCoalition in ipairs(self.CapturableCombatZones) do
        zoneCaptureCoalition:Stop()
    end
end

function COMBAT_ZONE_STATE_MACHINE:GetZoneCount(coalitionSide)
    return countTableEntries(self.CombatZones[coalitionSide])
end

function COMBAT_ZONE_STATE_MACHINE:EnableExpandingZones()
    self.__ExpandingZonesScheduler = SCHEDULER:New(self, function(machine)
        if machine:HasNeutralZones() then
            if WZ_CONFIG.debug then
                MESSAGE:New("Zones expanded.", 3, "DEBUG"):ToAll()
            end
            machine:UpdateAdjacentZones()
        end
    end, { self }, WZ_CONFIG.gameplay.expandZonesEvery, WZ_CONFIG.gameplay.expandZonesEvery)
    return self
end

function COMBAT_ZONE_STATE_MACHINE:EnableExpandingZoneTimer()
    self:DrawExpandingZoneTimer()
    self.__ExpandingZoneTimerScheduler = SCHEDULER:New(self, function(machine)
        if WZ_CONFIG.debug then
            MESSAGE:New("Zone timer ticked", 1, "DEBUG"):ToAll()
        end
        machine:TickExpandingZoneTimerClock()

        if not machine:HasNeutralZones() then
            machine:ClearMarkers()
            if machine.__ExpandingZoneTimerScheduler ~= nil then
                SCHEDULER:Remove(machine.__ExpandingZoneTimerScheduler)
                machine.__ExpandingZoneTimerScheduler = nil
            end
        end
    end, { self }, 1, 1)
    return self
end

--- Stops the state machine and resets it. Destroys all active NPC units and drawings.
function COMBAT_ZONE_STATE_MACHINE:Stop()
    if self.__GameUpdateScheduler ~= nil then
        SCHEDULER:Remove(self.__GameUpdateScheduler)
        self.__GameUpdateScheduler = nil
    end
    if self.__PlayerCheckScheduler ~= nil then
        SCHEDULER:Remove(self.__PlayerCheckScheduler)
        self.__PlayerCheckScheduler = nil
    end
    if self.__ExpandingZonesScheduler ~= nil then
        SCHEDULER:Remove(self.__ExpandingZonesScheduler)
        self.__ExpandingZonesScheduler = nil
    end
    if self.__ExpandingZoneTimerScheduler ~= nil then
        SCHEDULER:Remove(self.__ExpandingZoneTimerScheduler)
        self.__ExpandingZoneTimerScheduler = nil
    end
    for _, combatZone in ipairs(combineTables(self.CombatZones)) do
        combatZone:Destroy()
    end
    self:ClearMarkers()
    self:ClearCapturableCombatZones()
    self.__DrawnLines = {}
    self.CombatZones = {
        blue = {},
        red = {},
        neutral = {},
    }
    self.Missions = {}
    self.SpawnedGroups = {}
    self.GameEnded = false
    self.MainZone = {
        minX = 0,
        maxX = 0,
        minY = 0,
        maxY = 0,
        centerX = 0,
        centerY = 0,
        width = 0,
        height = 0,
    }
    self.HeadQuarters = {
        blue = nil,
        red = nil,
    }
    self.CapturableCombatZones = {}
    self.__CombatZoneCoalitionMap = {}
    self.__GameUpdateScheduler = nil
    self.__ExpandingZonesScheduler = nil
    self.__ExpandingZoneTimerScheduler = nil
    self.__SubZoneRadius = nil
    self.__DrawnLines = {}
    self.__Clients = {}
    self.__TimerMarkerId = nil
    self.__TimeLeftUntilNextExpandingZone = WZ_CONFIG.gameplay.expandZonesEvery
end