--[[

advanced-inserter 0.1.0, 2016-apr-18

This provides an inserter whose filters are controllable by the circuit network. See the 
forum post https://forums.factorio.com/viewtopic.php?f=93&t=23871 for purpose and usage details.

The way this works is relatively straightforward but it does contain a bunch of hacks.
There are three entity types involved here:

advanced-inserter: This is an actual inserter. It appears on the map. It is the item that
the player places, and it does the work.

advanced-inserter-lamp: There is one of these lamps per filter slot. They are used to read
circuit network conditions. Their conditions are set appropriately, then they are evaluated
and the advanced-inserter's corresponding filter slot is set/unset.

advanced-inserter-facade: This is what the user interacts with. It provides the GUI for
setting the items that the inserter will be able to move.

The various hurdles encountered, and reasons for the way this is done, in no specific order,
are:

  - Inexplicably, there is no API for reading circuit network signals. So we use lamps. They're as 
    good as anything else. Each one gets an individual signal to check (as its circuit condition)
	then we can evaluate the signal to see if its > 0 (or whatever). AFAIK there is no other
	way to evaluate multiple signals, at least not in one tick.
	
  - There is no API for easily controlling what an inserter inserts, so we use its filter
    slots.
	
  - Because we have to use lamps (or some other entity) to evaluate individual signals, we
    can't really create a lamp for every signal in the game. We don't even know them, because 
	there may be other mods, etc. That means the user has to provide a specific set of signals
	to look for. Which means we need a GUI to do that...
	
  - We can't use the advanced-inserter's GUI because we're already programmatically controlling
    its filter slots to control its behavior, so we have to use something else (unless we use only
	half, i.e. 2, of the filter slots, which kinda defeats the purpose, and also is confusing). The 
	game does not provide an API for overriding the settings GUI for an entity, so we have to use an 
	existing one. The only real option is to stick an invisible-but-selectable object on top
	of the advanced-inserter and use its GUI. And the only *real* option here is another inserter,
	because...
	
  - Constant combinators are the only other thing that lets you select a whole bunch of signals.
    But we can't use one here. For starters since the advanced-inserter isn't selectable and the
	constant-combinator doesn't have the yellow inserter arrows, it's kinda lame. More critically,
	the user can't connect the circuit wires to the advanced-inserter because it isn't selectable.
	That means they can only connect it to this "facade" object. But if we use a constant 
	combinator, it sends its signals out onto the network and undesirably modifies the players
	circuit network unless they set up other combinators as buffers or whatever, which would be
	annoying. So we need something that provides signal selection but doesn't modify the network
	it is connected to. So we can't use constant combinators. If I were better at prototyping I
	might be able to come up with something better by messing around with circuit wire connection
	points, but I don't really know how to do any of that. Feel free.
	
  - If we used a constant combinator we'd have to have control logic to manage this with only 5
    filter slots, which is tricky (but probably possible) if more than 5 items are specified by 
	the user. The game does not let us set more than 5 filter slots on an inserter, though, so we
	are limited to 5. 
	
So now we have this concept of a "facade" inserter, which is an invisible inserter that sits on
top of the real one. While the real one has a sprite and does all the work, the facade is what the
player has to interact with in order to provide a functioning settings GUI. So we have to do a lot
of things to make this at least somewhat transparent, including:

  - Player builds an advanced-inserter, but mines the facade. So mining the facade has to destroy
    the real inserter and lamps and stuff and return an advanced-inserter to the inventory.
	
  - Player can only connect circuit wires to facade, so we have to wire all our other stuff to
    that to interface with the player's circuit network.
	
  - Player can only set circuit and logistic network condition on facade so we have to keep the
    real inserter's conditions sync'd with it to make sure it behaves accordingly.
	
  - Player can only rotate the facade so we have to keep the real inserter's direction sync'd.
  
  - We only want the player to be able to collide with the facade, and only the facade should take
    damage, so we make everything else indestructable. 

  - Also we don't really want any of the hidden objects to unexpectedly use electricity, although
    we can't quite avoid it because any time energy usage of an object is set to 0, for some reason 
	it flashes the low-fuel icon, which is annoying and must be avoided.
	
I have no idea what strange bugs might be lurking in here. There are things that I do know about
that I can't really do anything about. See forum post for up-to-date info but, at least:

  - Electricity usage stats are weird. A bunch of lamps and smart inserters are added to the power
    consumption chart counts, although generally they'll be so low on the list as to not matter.
	
  - Related, the mouse-over power info is totally borked since its for the facade not the real 
    inserter, and we have to have the real inserter have the actual info (not the facade) so that 
	it maintains a reasonable power usage profile while running.
	
  - When you open the settings GUI, the sprite is blank. This is because it's for the invisible
    facade. There's no way to avoid this.

Until the game lets us override settings GUIs with our own, this isn't as useful as I want it to be
but still should be pretty useful, it's sort of like 5 smart inserters in 1.

There is another option here, which I plan on doing next, which is to create a "controller" that is
independent of an inserter, the same as Adil's approach in https://forums.factorio.com/viewtopic.php?f=93&t=14887.
which, after going through the hurdles here, I now appreciate much more. I considered this before
starting but decided to go with a pure inserter (although I did not realize it would be such a PITA).
--]]

require "defines"
require "util"


--[[
Print a message.
Copied from Choumiko's TFC (https://forums.factorio.com/viewtopic.php?f=92&t=4504)
--]]

function debugDump(var, force)
  if false or force then -- s/false/true when debugging
    for i,player in pairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end


function init ()

	debugDump("Initializing advanced-inserter...")
	global.ents = global.ents or {}

end


--[[
Offsets a position by a given amount when I'm debugging stuff.
--]]

function offset (position, xoff, yoff)

	if true then -- s/true/false when debugging to spread things out
		return position
	else
		return {
			x = position.x + xoff,
			y = position.y + yoff
		}
	end

end


--[[
Checks if a CircuitCondition is set. Doesn't work for combinators in 0.12.29 (use cond.parameters).
--]]

function is_condition_set (cond) 

	return cond and cond.condition and cond.condition.first_signal and cond.condition.first_signal.name
	
end


--[[
Update the real inserter's network conditions, using the following logic:

   - If force_deactivate is true then just clear the conditions so the inserter stops.
   - Otherwise if the facade's conditions are set update the inserter's to match. This gives the 
     user control over the conditions, since the real inserter is not selectable.
   - Otherwise set the circuit network condition to anything > 0. This'll be the default state.
     See code comments below for rationale.
	 
Preconditions:

   - ent.facade is set
   - ent.inserter is set
   
Postconditions:

   - ent.inserter's network conditions have been appropriately set.
   
This is called every tick.
--]]

function sync_network_conditions (ent, force_deactivate)

	local ccond
	local lcond

	if force_deactivate then
	
		-- we deactivate idle inserters by clearing their circuit conditions. see the comment about
		-- "busy" in update_filters for the rationale.
		ccond = nil
		lcond = nil
	
	else

		ccond = ent.facade.get_circuit_condition(defines.circuitconditionindex.inserter_circuit)
		lcond = ent.facade.get_circuit_condition(defines.circuitconditionindex.inserter_logistic)
		
		-- this is just a design choice: if neither condition is set, then set the circuit network
		-- condition to anything>0, since this lets the inserter function pretty much right out of
		-- the box. otherwise the player *has* to set up a network condition for every one to get it
		-- to work, and usually they'd want anything>0 anyways.
		if not (is_condition_set(ccond) or is_condition_set(lcond)) then
			ccond = {condition={
				comparator = ">",
				constant = 0,
				first_signal = { type="virtual", name="signal-anything" }
			}}
		end
		
	end
		
	ent.inserter.set_circuit_condition(defines.circuitconditionindex.inserter_circuit, ccond)
	ent.inserter.set_circuit_condition(defines.circuitconditionindex.inserter_logistic, lcond)

end


--[[
Update the lamps' network conditions to match the facade's filter settings. There is one lamp 
per filter slot, and each lamp's condition is set to that item > 0. Then later we can check if 
each lamp's condition is fulfilled and control the real inserter's filters based on that.

Preconditions:

  - ent.facade is set
  - ent.readers is an array with indices 1 through 5, each set to a lamp
  
Postconditions:

  - Each ent.readers condition set to match each ent.facade filter slot.

This is called every tick.
--]]

function sync_readers (ent) 
	
	for i = 1,5 do

		local newitem = ent.facade.get_filter(i)
		local curcond = ent.readers[i].get_circuit_condition(defines.circuitconditionindex.lamp)
		local curitem

		if is_condition_set(curcond) then
			curitem = curcond.condition.first_signal.name
		else
			curitem = nil
		end

		if curitem ~= newitem then
			local newcond
			if newitem then
				newcond = {condition={
					comparator = ">",   -- change this to < if you prefer
					constant = 0,
					first_signal = { type="item", name=newitem }
				}}
			else
				newcond = nil
			end
			ent.readers[i].set_circuit_condition(defines.circuitconditionindex.lamp, newcond)
			debugDump("filter "..i.." has changed")
		end

	end
	
end


--[[
Updates the real inserter's filter slots to match each lamps' circuit condition fulfillment
state. This is how we enable/disable specific items from circuit network conditions.

Preconditions:

  - ent.readers is set up and circuit conditions have been set
  - ent.inserter has been set
  
Postconditions:

  - ent.inserter's filter slots have been set to match network conditions.
  
Returns:

  - True if this inserter has things to move, false if it is idle. This is later passed to
    sync_network_conditions. See comments in code below for more info.
	
This is called every tick.
--]]

function update_filters (ent) 

	local busy = false

	for i = 1,5 do
	
		local cond = ent.readers[i].get_circuit_condition(defines.circuitconditionindex.lamp)
		
		-- get the item name from the condition, nil if nothing to move. this is what the
		-- lamps are for, as something to evaluate specific signals for us.
		local item
		if is_condition_set(cond) and cond.fulfilled then
			item = cond.condition.first_signal.name
		else
			item = nil
		end
		
		-- now use the inserter's filters to enable/disable this item
		if item then
			ent.inserter.set_filter(item, i)
			busy = true
		else
			ent.inserter.clear_filter(i)
		end
	
	end
	
	-- inserter must be stopped if there are no filters set, otherwise it'll just
	-- insert the freakin' shit out of everything. we'll use busy later to clear the
	-- network conditions and stop it that way (we could just set active=busy here
	-- but then the inserter stops in mid-swing and i don't like it).
	-- ent.inserter.active = busy
	return busy

end


--[[
Set up one of the lamps used to read the circuit network signals. I called them "readers"
because I was experimenting with different entities before settling on lamps. cindex is the
slot number and is only really used for setting the position offset during debugging.

Each lamp is connected to the facade with a red and a green wire. The player will be wiring
circuit networks to the facade so this is how the lamps connect.

The advanced-inserter-lamp is just a regular small-lamp but with an empty sprite.

Preconditions:

  - ent.inserter has been set
  - ent.facade has been set
  
Returns:

  - A new lamp.

This is called when building a new advanced-inserter.  
--]]

function setup_reader (ent, cindex)

	local reader = ent.inserter.surface.create_entity({
		name = "advanced-inserter-lamp", 
		position = offset(ent.inserter.position, cindex - 3, 2),
		force = game.player.force
	})
	
	reader.destructible = falsea

	ent.facade.connect_neighbour({
		wire = defines.circuitconnector.red,
		target_entity = reader
	})

	ent.facade.connect_neighbour({
		wire = defines.circuitconnector.green,
		target_entity = reader
	})

	return reader

end


--[[
Set up the facade. The purpose of this is explained in the file comments above. It is
connected to the real inserter with red and green circuit wires, so that the real
inserter's circuit network condition funcitions properly since the user can only wire
things to the facade.

The facade is created with the same direction as the real inserter so that the little
yellow arrows face the correct direction.

Note that 'entity' is an advanced-inserter here, not a global.ents entry.
  
Postconditions:

  - An advanced-inserter-facade has been created.
  
Returns:

  - The advanced-inserter-facade that was created.
  
This is called when building a new advanced-inserter.  
--]]

function setup_facade (entity) 

	local facade = entity.surface.create_entity({
		name = "advanced-inserter-facade",
		position = offset(entity.position, 0, -2),
		direction = entity.direction,
		force = game.player.force
	})

	-- the purpose of this connection is to still let the player connect circuit wires
	-- to the actual functioning inserter; it's done via the facade since the real guy
	-- isn't selectable.
	
	entity.connect_neighbour({
		wire = defines.circuitconnector.red,
		target_entity = facade
	})
	
	entity.connect_neighbour({
		wire = defines.circuitconnector.green,
		target_entity = facade
	})
	
	facade.active = false -- we don't want the fake inserter actually moving anything
	
	return facade

end


--[[
Update the inserter's state. This does everything.

Preconditions:

  - ent.inserter, ent.facade, and ent.readers are completely ready to go.
  
Postconditions:

  - All ent.inserter filter slots and network conditions have been appropriately set.
  
This is called every tick, and also right after setting everything up when building.
--]]

function do_update (ent) 

	sync_readers(ent)
	local busy = update_filters(ent)
	sync_network_conditions(ent, not busy)
	
end


--[[
Called on build events. Entity must be the advanced-inserter that was just built. Sets everything
up.

Postconditions:

  - A new, fully-initialized entry has been added to global.ent.
--]]

function do_build (entity) 

	local ent = {}
	ent.inserter = entity
	ent.inserter.destructible = false -- all interaction with world must be done through facade
	ent.facade = setup_facade(entity)
	ent.readers = {}
	ent.readers[1] = setup_reader(ent, 1)
	ent.readers[2] = setup_reader(ent, 2)
	ent.readers[3] = setup_reader(ent, 3)
	ent.readers[4] = setup_reader(ent, 4)
	ent.readers[5] = setup_reader(ent, 5)

	-- this doesn't *really* need to be done here, given defaults, but it makes me feel good
	do_update(ent)
	
	table.insert(global.ents, ent)
	debugDump("Built advanced inserter, now there are " .. #global.ents)
	
end


--[[
Destroy all objects except the facade, which is already being destroyed by the game. 

Postconditions:

  - The lamps in ent.readers have been destroyed.
  - The ent.inserter has been destroyed.
  
This is called when the facade is mined or otherwise destroyed.
--]]

function do_destroy_by_facade (ent)

	for i,r in ipairs(ent.readers) do
		r.destroy()
	end
	
	ent.inserter.destroy()
	
end


--[[
Given an advanced-inserter-facade, destroy the other associated objects and remove the
entry from global.ents.

Postconditions:

  - do_destroy_by_facade has been called on the associated global.ents entry.
  - The entry has been removed from global.ents.

This is called when the facade is mined or otherwise destroyed.
--]]

function do_remove_by_facade (entity)

	for i,e in ipairs(global.ents) do
		if (e.facade == entity) then
			do_destroy_by_facade(e)
			table.remove(global.ents, i)
			debugDump("Removed advanced inserter, now there are " .. #global.ents)
			break
		end
	end
	
end


--[[
Given an advanced-inserter-facade, update the direction of the associated 
advanced-inserter to match. This is the only way the player has to rotate the
real inserter.

Postconditions:

  - The associated advanced-inserter is now facing the same direction as the
    facade.
	
This is called in response to an entity rotation event.
--]]

function do_rotate_by_facade (entity) 

	for i,e in ipairs(global.ents) do
		if (e.facade == entity) then
			e.inserter.direction = e.facade.direction
		end
	end

end


-- event hooks ----------------------------------------------------------------

script.on_init(function() 
	init()
end)

script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity}, function (event)
	if event.created_entity.name == "advanced-inserter" then
		do_build(event.created_entity)
	end
end)

script.on_event({defines.events.on_entity_died,defines.events.on_robot_pre_mined,defines.events.on_preplayer_mined_item}, function(event)
	-- the player interacts with the facade
	if event.entity.name == "advanced-inserter-facade" then
		do_remove_by_facade(event.entity)
	end
end)

script.on_event({defines.events.on_player_rotated_entity}, function(event)
	-- the player interacts with the facade
	if event.entity.name == "advanced-inserter-facade" then
		do_rotate_by_facade(event.entity)
	end
end)

script.on_event(defines.events.on_tick, function(event)
	for i,ent in ipairs(global.ents) do
		do_update(ent)
	end
end)

script.on_configuration_changed(function(data)
	-- only use right now is to enable the recipe if advanced-electronics already researched.
	if data.mod_changes ~= nil and data.mod_changes["advanced-inserter"] ~= nil and data.mod_changes["advanced-inserter"].old_version == nil then
		for i, player in ipairs(game.players) do 
			if player.force.technologies["advanced-electronics"].researched then 
				player.force.recipes["advanced-inserter"].enabled = true
				debugDump("Mod installed; Advanced electronics researched, enabling Advanced Inserter.")
			end
		end
	end
end)
