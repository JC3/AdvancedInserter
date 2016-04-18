--[[
  Prototype for advanced-inserter-facade, which provides the GUI for the advanced-inserter
  and is what the player interacts with. See control.lua file comments for details. 
  Important things marked in comments below.
--]]

require "util"

local NAME = "advanced-inserter-facade"
local EMPTY_SPRITE = { filename="__advanced-inserter__/graphics/empty.png", width=0, height=0 }

local entity = table.deepcopy(data.raw.inserter["smart-inserter"])
entity.name = NAME
entity.max_health = 50
entity.minable.result = "advanced-inserter" -- player must mine facade, but they get their advanced-inserter back.
entity.energy_per_movement = 7700 -- doesn't really have an effect but at least makes info windows look right
entity.energy_per_rotation = 7700
entity.energy_source.drain = "0.40kW" -- ehhhh... energy use is complicated for this thing. see bugs in control.lua
-- it's invisible:
entity.hand_base_picture = EMPTY_SPRITE
entity.hand_closed_picture = EMPTY_SPRITE
entity.hand_open_picture = EMPTY_SPRITE
entity.hand_base_shadow = EMPTY_SPRITE
entity.hand_closed_shadow = EMPTY_SPRITE
entity.hand_open_shadow = EMPTY_SPRITE
entity.platform_picture.sheet = EMPTY_SPRITE
-- note we're still using the default smart-inserter's collision and selection boxes and stuff.

-- we don't really use the item but the game needs it.
local item = table.deepcopy(data.raw.item["smart-inserter"])
item.name = NAME
item.place_result = NAME
item.flags = {"hidden"} -- do not show in inventory

-- add our stuff
data:extend({entity, item})
