## API


### named_waypoints.register_named_waypoints = function(waypoints_type, waypoints_def)

	waypoints_def = {
		default_name = , -- a string that's used as the waypoint's label if a waypoint's data doesn't have a "name" property
		default_color = , -- label text color. If not defined defaults to 0xFFFFFFFF (opaque white)

		visibility_requires_item = , -- item string or "group:groupname", the player needs to have an item that matches this in their inventory to see waypoints on their HUD. If not defined then there's no requirement to see waypoints on the HUD.
		visibility_item_location = , -- "inventory", "hotbar", or "wielded" (defaults to inventory if not defined)

		visibility_volume_radius = , -- required. The radius within which a player will see the waypoint marked on their HUD
		visibility_volume_height = , -- if defined, then visibility check is done in a cylindrical volume rather than a sphere. Height extends both upward and downward from player position.

		discovery_requires_item = ,-- item string or "group:groupname", an item matching this is needed in player inventory for a waypoint to be marked as "discovered" for that player
		discovery_item_location = ,-- -- "inventory", "hotbar", "wielded" (defaults to inventory if not defined)

		discovery_volume_radius = , -- radius within which a waypoint can be auto-discovered by a player. "discovered_by" property is used in waypoint_data to store discovery info. If this is not defined then discovery is not required - waypoints will always be visible.
		discovery_volume_height = , -- if defined, then discovery check is done in a cylindrical volume rather than a sphere

		on_discovery = function(player, pos, waypoint_data, waypoint_def) -- use "named_waypoints.default_discovery_popup" for a generic discovery notification
	}

### named_waypoints.add_waypoint = function(waypoints_type, pos, waypoint_data)

waypoint_data is a freeform table you can put whatever you want into (though it will be stored as a serialized string so don't get fancy if you can avoid it). There are three properties on waypoint_data with special meaning:

	name = a string that will be used as the label for this waypoint (if not defined, named_waypoints will fall back to the "default_name" property of the waypoint definition)
	
	color = a hex integer that defines the colour of this waypoint (if not defined, named_waypoints will fall back to the "default_color" property of the waypoint definition, which itself falls back to 0xFFFFFFFF - opaque white)

	discovered_by = a set containing the names of players that have discovered this waypoint (provided discovery_volume_radius was defined)

If there's already a waypoint at pos this function will return false.

### named_waypoints.update_waypoint = function(waypoints_type, pos, waypoint_data)

The same as add_waypoint, but if there's already a waypoint at pos then the values of any fields in waypoint_data will replace the corresponding fields in the existing waypoint

### named_waypoints.get_waypoint = function(waypoints_type, pos)

Returns the waypoint_data of the waypoint at pos, or nil if there isn't one.

### named_waypoints.get_waypoints_in_area = function(waypoints_type, minp, maxp)

Returns a table with values of {pos = pos, data = waypoint_data} for all waypoints in the region specified.

### named_waypoints.remove_waypoint = function(waypoints_type, pos)

Deletes the waypoint at pos

### named_waypoints.reset_hud_markers = function(waypoint_type)

Causes all player HUD markers to be invalidated and refreshed.
