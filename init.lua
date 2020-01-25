local worldpath = minetest.get_worldpath()
--local modpath = minetest.get_modpath(minetest.get_current_modname())

local S = minetest.get_translator("named_waypoints")

named_wayponts = {}

local player_huds = {} -- Each player will have a table of [position_hash] = hud_id pairs in here
local waypoint_defs = {} -- the registered definition tables
local waypoint_areastores = {} -- areastores containing waypoint data

local inventory_string = "inventory"
local hotbar_string = "hotbar"
local wielded_string = "wielded"

--waypoint_def = {
--	default_name = , -- a string that's used if a waypoint's data doesn't have a "name" property
--	color = , -- if not defined, defaults to 0xFFFFFFFF
--	visibility_requires_item = , -- item, if not defined then nothing is required
--	visibility_item_location = , -- "inventory", "hotbar", "wielded" (defaults to inventory if not provided)
--	visibility_volume_radius = , -- required.
--	visibility_volume_height = , -- if defined, then visibility check is done in a cylindrical volume rather than a sphere
--	discovery_requires_item = ,-- item, if not defined then nothing is required
--	discovery_item_location = ,-- -- "inventory", "hotbar", "wielded" (defaults to inventory if not provided)
--	discovery_volume_radius = , -- radius within which a waypoint can be auto-discovered by a player. "discovered_by" property is used in waypoint_data to store discovery info
--	discovery_volume_height = , -- if defined, then discovery check is done in a cylindrical volume rather than a sphere
--	on_discovery = function(player, pos, waypoint_data, waypoint_def) -- use "named_waypoints.default_discovery_popup" for a generic discovery notification
--}

named_waypoints.register_named_waypoints = function(waypoints_type, waypoints_def)
	assert(waypoints_def.visibility_volume_radius)
	waypoint_defs[waypoints_type] = waypoints_def
	player_huds[waypoints_type] = {}

	local areastore_filename = worldpath.."/named_waypoints_".. waypoints_type ..".txt"
	local area_file = io.open(areastore_filename, "r")
	local areastore = AreaStore()
	if area_file then
		area_file:close()
		areastore:from_file(areastore_filename)
	end
	waypoint_areastores[waypoints_type] = areastore	
end

local function save(waypoints_type)
	local areastore_filename = worldpath.."/named_waypoints_".. waypoints_type ..".txt"
	local areastore = waypoint_areastores[waypoints_type]
	if areastore then
		areastore:to_file(areastore_filename)
	else
		minetest.log("error", "[named_waypoints] attempted to save areastore for unregistered type " .. waypoints_type)
	end
end

local function add_waypoint(waypoints_type, pos, waypoint_data, update_existing)
	assert(type(waypoint_data) == "table")
	local areastore = waypoint_areastores[waypoints_type]
	if not areastore then
		minetest.log("error", "[named_waypoints] attempted to add waypoint for unregistered type " .. waypoints_type)
		return false
	end
	local existing_area = areastore:get_areas_for_pos(pos, false, true)
	local id = next(existing_area)
	if id and not update_existing then
		return false -- already exists
	end	

	local data
	if id then
		local data = minetest.deserialize(existing_area[id].data)
		for k,v in pairs(waypoint_data) do
			data[k] = v
		end		
		areastore:remove_area(id)
	else
		data = waypoint_data
	end

	local waypoint_def = waypoint_defs[waypoints_type]
	if not (data.name or waypoint_def.default_name) then
		minetest.log("error", "[named_waypoints] Waypoint of type " .. waypoints_type .. " at "
			.. minetest.pos_to_string(pos) .. " was missing a name field in its data " .. dump(data)
			.. " and its type definition has no default to fall back on.")
		return false
	end
	areastore:insert_area(pos, pos, minetest.serialize(data), id)
	save(waypoints_type)
	return true	
end

named_waypoints.add_waypoint = function(waypoints_type, pos, waypoint_data)
	return add_waypoint(waypoints_type, pos, waypoint_data, false)
end

named_waypoints.update_waypoint = function(waypoints_type, pos, waypoint_data)
	return add_waypoint(waypoints_type, pos, waypoint_data, true)
end

named_waypoints.get_waypoint = function(waypoints_type, pos)
	local areastore = waypoint_areastores[waypoints_type]
	local existing_area = areastore:get_areas_for_pos(pos, false, true)
	local id = next(existing_area)
	if not id then
		return nil -- nothing here
	end	
	return minetest.deserialize(existing_area[id].data)
end

-- returns a list of tables with the values {pos=, data=}
named_waypoints.get_waypoints_in_area = function(waypoints_type, minp, maxp)
	local areastore = waypoint_areastores[waypoints_type]
	local areas = areastore:get_areas_in_area(minp, maxp, true, true, true)
	local returnval = {}
	for id, data in pairs(areas) do
		table.insert(returnval, {pos=data.min, data=minetest.deserialize(data.data)})
	end
	return returnval
end

named_waypoints.remove_waypoint = function(waypoints_type, pos)
	local areastore = waypoint_areastores[waypoints_type]
	local existing_area = areastore:get_areas_for_pos(pos, false, true)
	local id = next(existing_area)
	if not id then
		return false -- nothing here
	end
	areastore:remove_area(id)
	save(waypoints_type)
	return true
end

local function add_hud_marker(waypoints_type, player, player_name, pos, label, color)
	local waypoints_for_this_type = player_huds[waypoints_type]
	local waypoints = waypoints_for_this_type[player_name] or {}
	local pos_hash = minetest.hash_node_position(pos)
	if waypoints[pos_hash] then
		-- already exists
		return
	end
	waypoints_for_this_type[player_name] = waypoints
	color = color or 0xFFFFFF
	local hud_id = player:hud_add({
		hud_elem_type = "waypoint",
		name = label,
		text = "m",
		number = color,
		world_pos = pos})
	waypoints[pos_hash] = hud_id
end

local grouplen = #"group:"
local function test_items(player, item, location)
	location = location or inventory_string
	local group
	if item:sub(1,grouplen) == "group:" then
		group = item:sub(grouplen+1)
	end
	
	if location == inventory_string then
		local player_inv = player:get_inventory()
		if group then
			for _, itemstack in pairs(player_inv:get_list("main")) do
				if mintest.get_item_group(itemstack:get_name(), group) > 0 then
					return true
				end
			end
		elseif player_inv:contains_item("main", ItemStack(item)) then
			return true
		end

	elseif location == hotbar_string then
		if group then
			for i = 1,8 do
				local hot_item = player_inv:get_Stack("main", i)
				if minetest.get_item_group(hot_item:get_name(), group) > 0 then
					return true
				end
			end
		else
			local hot_required = ItemStack(hot)
			for i = 1, 8 do
				local hot_item = player_inv:get_Stack("main", i)
				if hot_item:get_name() == hot_required:get_name() and hot_item:get_count() >= hot_required:get_count() then
					return true
				end
			end
		end

	elseif location == wielded_string then
		local wielded_item = player:get_wielded_item()
		if group then
			return minetest.get_item_group(wielded_item:get_name(), group) > 0
		else
			local wielded_required = ItemStack(hand)
			if wielded_item:get_name() == wielded_required:get_name() and wielded_item:get_count() >= wielded_required:get_count() then
				return true
			end
		end
	else
		minetest.log("error", "[named_waypoints] Illegal inventory location " .. location .. " to test for an item.")
	end
	return false
end

local function test_range(player_pos, waypoint_pos, volume_radius, volume_height)
	if volume_height then
		if math.abs(player_pos.y - waypoint_pos.y) > volume_height then
			return false
		end
		return math.sqrt(
			((player_pos.x - waypoint_pos.x)*(player_pos.x - waypoint_pos.x))+
			((player_pos.z - waypoint_pos.z)*(player_pos.z - waypoint_pos.z))) <= volume_radius
	else
		return vector.distance(player_pos, waypoint_pos <= volume_radius)
	end
end

-- doesn't test for discovery status being lost, it is assumed that waypoints are
-- rarely ever un-discovered once discovered.
local function remove_distant_hud_markers(waypoint_type)
	local waypoints_for_this_type = player_huds[waypoint_type]
	local players_to_remove = {}
	local waypoint_def = waypoint_defs[waypoint_type]
	local vis_inv = waypoint_def.visibility_requires_item
	local vis_loc = waypoint_def.visibility_item_location
	local vis_radius = waypoint_def.visibility_volume_radius
	local vis_height = waypoint_def.visibility_volume_height

	for player_name, waypoints in pairs(waypoints_for_this_type) do
		local player = minetest.get_player_by_name(player_name)
		if player then
			local waypoints_to_remove = {}
			local player_pos = player:get_pos()
			for pos_hash, hud_id in pairs(waypoints) do
				local pos = minetest.get_position_from_hash(pos_hash)
				if not (test_items(player, vis_inv, vis_loc) 
					and test_range(player_pos, pos, vis_radius, vis_height)) then
					table.insert(waypoints_to_remove, pos_hash)
					player:hud_remove(hud_id)
				end
			end
			for _, pos_hash in ipairs(waypoints_to_remove) do
				waypoints[pos_hash] = nil
			end
			if not next(waypoints) then -- player's waypoint list is empty, remove it
				table.insert(players_to_remove, player_name)
			end
		else
			table.insert(players_to_remove, player_name)
		end
	end
	for _, player_name in ipairs(players_to_remove) do
		player_huds[player_name] = nil
	end
end

-- For flushing outdated HUD markers when certain admin commands are performed.
named_waypoints.reset_hud_markers = function(waypoint_type)
	local waypoints_for_this_type = player_huds[waypoint_type]
	for player_name, waypoints in pairs(waypoints_for_this_type) do
		local player = minetest.get_player_by_name(player_name)
		if player then
			for pos_hash, hud_id in pairs(waypoints) do
				player:hud_remove(hud_id)
			end
		end
	end
	player_huds[waypoint_type] = {}
end

local function get_range_box(pos, volume_radius, volume_height)
	if volume_height then
		return {x = pos.x - volume_radius, y = pos.y - volume_height, z = pos.z - volume_radius},
			{x = pos.x + volume_radius, y = pos.y + volume_height, z = pos.z + volume_radius}
	else
		return vector.subtract(pos, volume_radius), vector.add(pos, volume_radius)
	end
end

local elapsed = 0
minetest.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < test_interval then
		return
	end
	elapsed = 0

	local connected_players = minetest.get_connected_players()
	for waypoint_type, waypoint_def in pairs(waypoint_defs) do
		local areastore = waypoint_areastores[waypoint_type]
		local dirty_areastore = false
		
		local vis_radius = waypoint_def.visibility_volume_radius
		local vis_height = waypoint_def.visibility_volume_height
		local vis_inv = waypoint_def.visibility_requires_item
		local vis_loc = waypoint_def.visibility_item_location
		
		local disc_radius = waypoint_def.discovery_volume_radius
		local disc_height = waypoint_def.discovery_volume_height
		local disc_inv = waypoint_def.discovery_requires_item
		local disc_loc = waypoint_def.discovery_item_location
		
		local on_discovery = waypoint_def.on_discovery
		local color = waypoint_def.color
	
		for _, player in ipairs(connected_players) do
			local player_pos = player:get_pos()
			local player_name = player:get_player_name()
			
			if disc_radius then			
				local min_discovery_edge, max_discovery_edge = get_range_box(player_pos, disc_radius, disc_height)
				local potentially_discoverable = areastore:get_areas_in_area(min_discovery_edge, max_discovery_edge, true, true, true)
				for id, area_data in pairs(potentially_discoverable) do
					local pos = area_data.min
					local data = minetest.deserialize(area_data.data)
					local discovered_by = data.discovered_by or {}
	
					if (not discovered_by or discovered_by[player_name]) and
						test_items(player, disc_inv, disc_loc) 
						and test_range(player_pos, pos, disc_radius, disc_height) then
						
						discovered_by[player_name] = true
						data.discovered_by = discovered_by
						areastore:remove_area(id)
						areastore:insert_area(pos, pos, minetest.serialize(data), id)
						
						if on_discovery then
							on_discovery(player, pos, data, waypoint_def)
						end
						
						dirty_areastore = true						
					end
				end			
			end

			local min_visual_edge, max_visual_edge = get_range_box(player_pos, vis_radius, vis_height)
			local potentially_visible = areastore:get_areas_in_area(min_visual_edge, max_visual_edge, true, true, true)
			for id, area_data in pairs(potentially_visible) do
				local pos = area_data.min
				local data = minetest.deserialize(area_data.data)
				local discovered_by = data.discovered_by

				if (not disc_radius or (discovered_by and discovered_by[player_name])) and
					test_items(player, vis_inv, vis_loc) 
					and test_range(player_pos, pos, vis_radius, vis_height) then
					add_hud_marker(waypoint_type, player, player_name, pos, data.name or waypoint_def.default_name, color)
				end
			end
		end
		if dirty_areastore then
			save(waypoint_type)
		end
		remove_distant_hud_markers(waypoint_type)
	end
end)

-- Use this as a definition's on_discovery for a generic popup and sound alert
named_waypoints.default_discovery_popup = function(player, pos, data, waypoint_def)
	local player_name = player:get_player_name()
	local discovery_name = data.name or waypoint_def.default_name
	local discovery_note = S("You've discovered @1", discovery_name)
	local formspec = "size[4,1]" ..
		"label[1.0,0.0;" .. minetest.formspec_escape(discovery_note) ..
		"]button_exit[0.5,0.75;3,0.5;btn_ok;".. S("OK") .."]"
	minetest.show_formspec(player_name, "named_waypoints:discovery_popup", formspec)
	minetest.chat_send_player(player_name, discovery_note)
	minetest.log("action", "[named_waypoints] " .. player_name .. " discovered " .. discovery_name)
	minetest.sound_play({name = "named_waypoints_chime01", gain = 0.25}, {to_player=player_name})
end