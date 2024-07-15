if not WZ_CONFIG then
    WZ_CONFIG = {
        debug = true, -- Show debug messages
        zone = {
            subdivisions = 6, -- Grid size (e.g. 6 = 6x6, 7 = 7x7, etc.)
            yOffset = 0, -- Move all markers up and down
            xOffset = 0, -- Move all markers left and right
            markers = {
                enable = true, -- Show markers in the center of the zones
                textFormat = "Capture Zone %d-%d" -- Text that the markers show, accepts two %d for Row / Col index
            }
        },
    }
end