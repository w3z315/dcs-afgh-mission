if not WZ_CONFIG then
    WZ_CONFIG = {
        debug = false, -- Show debug messages
        zone = {
            name = "Zone_Polygon_Area", -- The name of the polygon map marking in which to generate the combat zones
            subZoneRadiusX = 20000,
            subZoneRadiusY = 20000,
            spacingX = 500,
            spacingY = 500,
            lineMaxDistance = 100000, -- Max distance between two zones to count as adjacent
            yOffset = 0, -- Move all markers up and down
            xOffset = 0, -- Move all markers left and right
            markers = {
                enable = true, -- Show markers in the area of the zones,
                enableCapturingStatus = true, -- If set to true the map marker will show that the site is being captured
                textFormat = "Capture Zone %d-%d" -- Text that the markers show, accepts two %d for Row / Col index
            },
        },
        gameplay = {
            enableExpandingZones = true, -- Automatically expand zones with some factors to make the mission quicker
            enableExpandingZoneTimer = true, -- Show a timer on the map that displays the time until the troops will capture adjacent zones
            maxSimultaniouslyExpandedZones = 2, -- Set to 0 if you want all adjacent
            expandZonesEvery = 900, -- Auto expand every x seconds, default = 15min (900),
            winningSideProbability = 0.5, -- The probability the winning side automatically gets a new zone (0.0 - 1.0),
            updateZonesEvery = 3, -- How often (seconds) do we want to check the zones for updates (e.g. Coalition), default 3 - Set to higher value if you are running into performance issues
            updatePlayerStatusEvery = 3, -- How often (seconds) do we want to check players for updates (can be a lot faster)
            restartAfterMissionEnds = true, -- Should the mission restart when someone won?
            restartAfterSeconds = 60, -- After how many seconds should the mission restart?,
            spawnUnitsInRadius = 5000, -- Which radius should the spawn zone have? (metric) Default 1500
        },
        audio = {
            missionIntroSound = false, -- Play a intro when a user joins the mission for the first time
            missionIntroSoundFile = "intro.ogg", -- Sound file name. Add this as a trigger to your mission (play to neutral once) so it gets inserted into the mission and we can play it as intro.
        },
        messages = { -- Messages that will be shown to the users. Make sure to keep %d wherever it is needed (exact amount!)
            missionIntro = "Welcome to Weazel's zone fun! \n\nYour objective is to capture all designated zones on the battlefield. \nUse the F10 map to locate these zones. To secure a zone, you and your team must enter the zone and eliminate all enemy units within. \nIf the automatic capture feature is enabled, zones will be captured by their respective forces over time. \n\nVictory is achieved when one side controls all the zones. \nGood luck, pilots, and may the best team win!",
            expandingZones = {
                blueMessage = "Our ground units have captured %d new zone(s) for the Blue Side. Enemy ground forces have secured %d new zone(s) for the Red Side.",
                redMessage = "Enemy ground forces have secured %d new zone(s) for the Red Side. Our ground units have captured %d new zone(s) for the Blue Side.",
            },
            win = {
                blueMessage = "BLUE HAS WON!\n\nCongratulations to the brave pilots of the BLUE team!\nZones captured: %d",
                redMessage = "RED HAS WON!\n\nHail to the victorious RED team!\nZones captured: %d",
            }
        },
        groups = {
            defensiveGroupCopyAreaName = "TemplateZone_FOB", -- Copies groups and statics from this area
            defensiveGroupCopyNamePattern = "ZoneTemplate", -- Name prefix the groups have to have
        },
        statics = {
            headQuarters = { -- Static objects for the COMMANDCENTERs - MUST BE PRESENT IN MISSION EDITOR (can be anything)
                blue = {
                    groupName = "BLUEHQ", -- The actual group name of the static
                    prettyName = "Blue Headquarters", -- A pretty name for texts to players
                },
                red = {
                    groupName = "REDHQ", -- The actual group name of the static
                    prettyName = "Red Headquarters", -- A pretty name for texts to players
                },
            },
            farps = {
                "FARP-1-1",
                "FARP-2-1",
                "FARP-3-1",
                "FARP-4-1",
                "FARP-5-1",
                "FARP-6-1",
                "FARP-7-1",
                "FARP-8-1",
                "FARP-9-1",
                "FARP-10-1",
                "FARP-11-1",
                "FARP-12-1",
                "FARP-13-1",
                "FARP-14-1",
                "FARP-15-1",
            },
        },
    }
end