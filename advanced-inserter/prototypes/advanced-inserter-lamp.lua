--[[
  Prototype for the advanced-inserter-lamp, which is basically a small-lamp with an
  empty sprite. If anybody knows better ways of making an object invisible please share.
  See control.lua file comments for explanation. Important things marked in comments 
  below.
--]]

require "util"

local NAME = "advanced-inserter-lamp"
local EMPTY_SPRITE = { filename="__advanced-inserter__/graphics/empty.png", width=0, height=0 }

local entity = table.deepcopy(data.raw.lamp["small-lamp"])
entity.name = NAME
entity.minable.minable = false -- don't let player mine this; they mine the facade
entity.energy_usage_per_tick = "0.1kW" -- can't be 0 or we get flashing no-energy icon
-- small collision box ensures player collides with facade
entity.collision_box = {{-0.01, -0.01}, {0.01, 0.01}}
entity.selection_box = {{-0.01, -0.01}, {0.01, 0.01}}
entity.selectable_in_game = false -- don't let player select this; the select the facade
entity.light = {intensity=0,size=0} -- don't actually emit light
entity.picture_on = EMPTY_SPRITE -- invisible
entity.picture_off = EMPTY_SPRITE

-- the item isn't really used but it needs to exist for the game.
local item = table.deepcopy(data.raw.item["small-lamp"])
item.name = NAME
item.place_result = NAME
item.flags = {"hidden"} -- don't show item in inventory

-- add our stuff
data:extend({entity, item})
