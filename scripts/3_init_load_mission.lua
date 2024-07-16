WZ_CONFIG = WZ_CONFIG or {}

-- Define the main zone
local mainZone = POLYGON:FindOnMap(WZ_CONFIG.zone.name)

local stateMachine = COMBAT_ZONE_STATE_MACHINE:New():Begin(mainZone)

if WZ_CONFIG.gameplay.enableExpandingZones then
    MESSAGE:New(string.format("Expanding zones enabled! Expanding sides every %d seconds.", WZ_CONFIG.gameplay.expandZonesEvery), 30, "GAMEPLAY INFO"):ToAll()
    stateMachine:EnableExpandingZones()

    if WZ_CONFIG.gameplay.enableExpandingZoneTimer then
        stateMachine:EnableExpandingZoneTimer()
    end
end

if WZ_CONFIG.debug then
    MESSAGE:New(string.format("Total amount of blue zones: %d", stateMachine:GetZoneCount("blue")), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of red zones: %d", stateMachine:GetZoneCount("red")), 25, "DEBUG"):ToAll()
    MESSAGE:New(string.format("Total amount of neutral: %d", stateMachine:GetZoneCount("neutral")), 25, "DEBUG"):ToAll()
end
