--[[
  Prototype for advanced-inserter-facade, which provides the GUI for the advanced-inserter
  and is what the player interacts with. See control.lua file comments for details. 
  Important things marked in comments below.
--]]

require "util"

local NAME = "advanced-inserter-facade-output"


local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = NAME
entity.icon = "__advanced-inserter__/graphics/output.png"
entity.sprite.filename="__advanced-inserter__/graphics/output.png"
entity.minable = {hardness = 100, mining_time = 100, result = "constant-combinator"}
-- note we're still using the default smart-inserter's collision and selection boxes and stuff.


-- we don't really use the item but the game needs it.
local item = table.deepcopy(data.raw.item["constant-combinator"])
item.name = NAME
item.place_result = NAME
item.flags = {"hidden"} -- do not show in inventory



-- add our stuff
data:extend({entity, item})