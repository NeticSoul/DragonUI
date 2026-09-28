-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local unpack = unpack

local VEHICLE_ART_DIR = "Interface\\Vehicles\\"

local BLIZZARD_SHEETS = {
    elements = VEHICLE_ART_DIR .. "UI-Vehicles-Elements-Organic",
    border   = VEHICLE_ART_DIR .. "UI-Vehicle-Frame-Border-Organic",
    bottle   = VEHICLE_ART_DIR .. "UI-Vehicles-Endcap-Organic-bottle",
}

local function ResolveSheet(key)
    if key == "gears" then
        return addon._dir .. "ActionBars\\mechanical2"
    end
    return BLIZZARD_SHEETS[key]
end

local SKIN_PIECES = {
    -- Texcoords past 1 are intentional for the 800-wide layout; never add a tiling flag.
    organic = {
        { "BACKGROUND", 1, "elements", 470, 85,  "BOTTOMRIGHT", -170, 0,   0,          1.8359375,  0.68359375, 1          },
        { "BORDER",     1, "elements", 76,  91,  "BOTTOMRIGHT", -161, -10, 0.00390625, 0.30078125, 0.3203125,  0.67578125 },
        { "BORDER",     2, "border",   468, 16,  "BOTTOMRIGHT", -170, 79,  0,          8.3125,     0,          1          },
        { "BORDER",     3, "elements", 17,  84,  "BOTTOMRIGHT", -247, 0,   0.93359375, 1,          0.3515625,  0.6796875  },
        { "BORDER",     4, "border",   378, 16,  "BOTTOMRIGHT", -257, 0,   0,          8.3125,     0,          1          },
        { "ARTWORK",    1, "elements", 92,  26,  "BOTTOMRIGHT", -159, 73,  0.640625,   1,          0.0546875,  0.15625    },
        { "ARTWORK",    2, "elements", 110, 25,  "BOTTOMLEFT",  161,  76,  0,          0.4296875,  0.0390625,  0.13671875 },
        { "ARTWORK",    3, "elements", 77,  20,  "BOTTOMRIGHT", -252, -3,  0.640625,   1,          0.0546875,  0.15625    },
        { "ARTWORK",    4, "elements", 77,  20,  "BOTTOMRIGHT", -559, -3,  1,          0.640625,   0.0546875,  0.15625    },
        { "ARTWORK",    5, "elements", 31,  21,  "BOTTOMRIGHT", -252, 75,  0.640625,   0.78125,    0.06640625, 0.15625    },
        { "OVERLAY",    1, "bottle",   114, 128, "BOTTOMLEFT",  5,    -15, 0,          0.4453125,  0,          1          },
        { "OVERLAY",    2, "bottle",   114, 128, "BOTTOMRIGHT", -6,   -15, 0.4453125,  0,          0,          1          },
        { "OVERLAY",    3, "bottle",   9,   103, "BOTTOMRIGHT", -158, 0,   0.71484375, 0.7578125,  0,          1          },
        { "OVERLAY",    4, "bottle",   9,   103, "BOTTOMLEFT",  158,  0,   0.7578125,  0.71484375, 0,          1          },
    },
    mechanical = {
        { "BACKGROUND", 1, "gears",  546, 88,  "BOTTOMRIGHT", -140, 0,   0,           0.99609375,  0.173828125, 0.353515625 },
        { "BORDER",     2, "gears",  538, 26,  "BOTTOMRIGHT", -141, 78,  0,           0.99609375,  0.017578125, 0.056640625 },
        { "OVERLAY",    1, "gears",  121, 128, "BOTTOMLEFT",  -36,  -15, 0.060546875, 0.283203125, 0.76953125,  0.98828125  },
        { "OVERLAY",    2, "gears",  121, 128, "BOTTOMRIGHT", 16,   -15, 0.283203125, 0.060546875, 0.76953125,  0.98828125  },
        { "OVERLAY",    3, "bottle", 9,   108, "BOTTOMRIGHT", -135, 0,   0.71484375,  0.7578125,   0,           1           },
        { "OVERLAY",    4, "bottle", 9,   108, "BOTTOMLEFT",  114,  0,   0.7578125,   0.71484375,  0,           1           },
    },
}

-- Mirrors XML $parent: unnamed containers take the root's name, so both skins share one prefix.
local function GlobalPrefix(container)
    local own = container:GetName()
    if own then
        return own
    end
    local root = container:GetParent()
    return root and root:GetName()
end

-- utils.xml declares OrganicArt first, so MechanicalArt wins the shared globals vehicle.lua reads.
local function BuildVehicleArt(container, skin)
    local pieces = SKIN_PIECES[skin]
    if not pieces then
        return
    end
    local prefix = GlobalPrefix(container)
    for i = 1, #pieces do
        local layer, n, sheet, w, h, point, x, y, left, right, top, bottom = unpack(pieces[i])
        local piece = container:CreateTexture(prefix and (prefix .. layer .. n), layer)
        piece:SetTexture(ResolveSheet(sheet))
        piece:SetTexCoord(left, right, top, bottom)
        piece:SetSize(w, h)
        piece:SetPoint(point, container, point, x, y)
    end
end

addon.BuildVehicleArt = BuildVehicleArt
