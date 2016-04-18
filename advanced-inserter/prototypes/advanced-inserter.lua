--[[ 
  Prototype for the advanced-inserter. This is the inserter that displays on the screen and
  does all the work, although it is not the one the player interacts with. See control.lua
  comments for explanation. Important things have been marked in comments below.
--]]

require "util"

local GFX_PREFIX = "__advanced-inserter__/graphics/advanced-inserter"
local ICON = GFX_PREFIX .. "-icon.png"
local NAME = "advanced-inserter"

-- todo: turns out i could have just added tint here instead of making new pictures. do that.
local entity = table.deepcopy(data.raw.inserter["smart-inserter"])
entity.name = NAME
entity.energy_per_movement = 7700
entity.energy_per_rotation = 7700
entity.energy_source.drain = "0.40kW"
entity.icon = ICON
entity.hand_base_picture.filename = GFX_PREFIX .. "-hand-base.png"
entity.hand_closed_picture.filename = GFX_PREFIX .. "-hand-closed.png"
entity.hand_open_picture.filename = GFX_PREFIX .. "-hand-open.png"
entity.platform_picture.sheet.filename = GFX_PREFIX .. "-platform.png"
entity.minable.minable = false     -- do not let the player mine this. they mine the facade.
-- boxes should be as small as possible. they can't be empty or the inserter arrows get all
-- screwed up. collisions will happen with the facade since that box is bigger.
entity.collision_box = {{-0.01, -0.01}, {0.01, 0.01}} 
entity.selection_box = {{-0.01, -0.01}, {0.01, 0.01}} 
entity.selectable_in_game = false  -- do not let player select this. they select the facade.

-- based on smart inserter
local item = table.deepcopy(data.raw.item["smart-inserter"])
item.name = NAME
item.icon = ICON
item.order = "f[inserter]-f[" .. NAME .. "]"
item.place_result = NAME

-- seems like a reasonable recipe
local recipe = {
	type = "recipe",
	name = NAME,
	enabled = false,
	ingredients =
	{
	  {"smart-inserter", 1},
	  {"advanced-circuit", 2}
	},
	result = NAME
}

-- add our stuff. tech comes with advanced electronics, like smart inserter 
-- comes with electronics
data:extend({entity, item, recipe})
table.insert(data.raw["technology"]["advanced-electronics"].effects, { type = "unlock-recipe", recipe = NAME})

