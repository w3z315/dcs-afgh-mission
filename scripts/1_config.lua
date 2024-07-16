if not WZ_CONFIG then
    WZ_CONFIG = {
        debug = true, -- Show debug messages
        zone = {
            name = "Zone_Polygon_Area",
            subdivisions = 5, -- Grid size (e.g. 6 = 6x6, 7 = 7x7, etc.)
            lineMaxDistance = 80000, -- Max distance between two zones to count as adjacent
            yOffset = 0, -- Move all markers up and down
            xOffset = 0, -- Move all markers left and right
            markers = {
                enable = true, -- Show markers in the center of the zones
                textFormat = "CaptureZone_%d_%d" -- Text that the markers show, accepts two %d for Row / Col index
            }
        },
        gameplay = {
            enableExpandingZones = true, -- Automatically expand zones with some factors to make the mission quicker
            expandZonesEvery = 6, -- Auto expand every x seconds, default = 5min (300),
            winningSideProbability = 0.5, -- The probability the winning side automatically gets a new zone (0-1),
            updateZonesEvery = 3, -- How often (seconds) do we want to check the zones for updates (e.g. Coalition), default 3,
            restartAfterMissionEnds = false, -- Should the mission restart when someone won?
            restartAfterSeconds = 60, -- After how many seconds should the mission restart?
        },
        groups = {
            defensive = {
                "ZoneTemplate | SA-2 ",
                "ZoneTemplate | AAA",
                "ZoneTemplate | Bunker 1",
            }
        },
        statics = {
            defensive = {
                "ZoneTemplate | Tank-1",
                "ZoneTemplate | Tank-1-1",
                "ZoneTemplate | Tank-2-1",
                "ZoneTemplate | Comms-1",
                --"ZoneTemplate | FARP1",
            }
        },
    }
end