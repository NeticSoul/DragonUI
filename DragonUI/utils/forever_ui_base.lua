-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Forever (c60) art kit: atlas data lives in addon.ForeverAtlas, widgets in addon.ForeverUI.
local ForeverAtlas = addon.ForeverAtlas or {}
local ForeverUI = addon.ForeverUI or {}
addon.ForeverAtlas = ForeverAtlas
addon.ForeverUI = ForeverUI

ForeverUI.TEXTURE_DIR = addon._dir .. "ForeverUI\\"

-- Entries are { sheet, w, h, left, right, top, bottom }: w/h in UI units, coords as sheet fractions.
function ForeverUI.GetAtlas(name)
    return name and ForeverAtlas[name]
end

function ForeverUI.SetAtlas(texture, name, useAtlasSize)
    local info = name and ForeverAtlas[name]
    if not (texture and info) then
        return false
    end
    texture:SetTexture(info[1])
    texture:SetTexCoord(info[4], info[5], info[6], info[7])
    if useAtlasSize then
        texture:SetSize(info[2], info[3])
    end
    return true
end
