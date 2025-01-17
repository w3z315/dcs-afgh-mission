WZ_CONFIG = WZ_CONFIG or {}
BASE:TraceOnOff(WZ_CONFIG.debug)




-- Define the main zone
local mainZone = POLYGON:FindOnMap(WZ_CONFIG.zone.name)

WZ_stateMachine = COMBAT_ZONE_STATE_MACHINE:New():Begin(mainZone)

if WZ_CONFIG.gameplay.enableExpandingZones then
    MESSAGE:New(string.format("Expanding zones enabled! Expanding sides every %d seconds.", WZ_CONFIG.gameplay.expandZonesEvery), 30, "GAMEPLAY INFO"):ToAll()
    WZ_stateMachine:EnableExpandingZones()

    if WZ_CONFIG.gameplay.enableExpandingZoneTimer then
        WZ_stateMachine:EnableExpandingZoneTimer()
    end
end

-- Pilot destruction event handler
local PilotDestructionHandler = EVENTHANDLER:New()
PilotDestructionHandler:HandleEvent(EVENTS.LandingAfterEjection)

function PilotDestructionHandler:OnEventLandingAfterEjection(EventData)
    local spawnedObject = EventData.IniDCSUnit
    self:I(spawnedObject)
    if spawnedObject then
        spawnedObject:destroy()
        self:E("Pilot ejected, landed and destroyed: " .. EventData.IniDCSUnitName)
    end
    self:E("Pilot ejected and landed.")
end



if WZ_CONFIG.debug then
    MESSAGE:New(string.format("Total amount of blue zones: %d", WZ_stateMachine:GetZoneCount("blue")), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of red zones: %d", WZ_stateMachine:GetZoneCount("red")), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of neutral: %d", WZ_stateMachine:GetZoneCount("neutral")), 25, "DEBUG"):ToAll()
end