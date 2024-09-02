# Represents a hex-based map
class_name HexMap extends Node2D

const SQRT3 = sqrt(3)

# Radius of map in hexes
@export var radius: int = 20
# Radius of a hex in pixels
@export var hex_radius: int = 200
# Node type we should use when we build out our map
@export var hex_scene: PackedScene

# Emitted when a hex is hovered on or off
signal hex_hover(hex: HexNode, state: bool)
# Emitted when a hex is clicked or tapped
signal hex_clicked(hex: HexNode, index: int, state: bool)

# Hex math values
var hex_width = SQRT3 * hex_radius
var hex_height = 2 * hex_radius

# Map of hex location keys to hex nodes
var hexes = {}
# List of all objects contained in map
var objects = []

# Set up nodes on entering the tree
func _ready():
	# Set up layers
#	this.hexLayer = this.addChild(new Container(this.scene));
#	this.underlay = this.addChild(new MapUnderlay(this.scene, { map: this }));
#	this.objectLayer = this.addChild(new Container(this.scene));
#	this.overlay = this.addChild(new Container(this.scene));
	# Set up tiles
	generate_tiles()
	setup_camera()

func generate_tiles():
	# Start at center
	var loc = HexLoc.new(0,0)
	add_hex(loc)

	# Add radius rings
	for i in range(1, radius + 1):
		loc.update(0, 0)
		loc.offset_dir(HexDir.UPLEFT, i)
		for dir in range(6):
			for step in range(i):
				add_hex(loc)
				loc.offset_dir(dir, 1)

	HexLoc.new(0,0).dir_to(HexLoc.new(1,0))
	HexLoc.new(0,0).dir_to(HexLoc.new(0,1))
	HexLoc.new(0,0).dir_to(HexLoc.new(-1,1))

func setup_camera():
	var bounds = get_bounds()
	bounds.grow(200)

func get_bounds():
	var width = (radius * 2 + 1) * hex_radius * SQRT3
	var height = hex_radius * 2 + (radius * 2) * hex_radius * 3.0 / 2
	return Rect2(-width / 2.0, -height / 2.0, width, height)

func add_object(obj: HexObject, loc: HexLoc, dir = HexDir.RIGHT):
	obj.map = self
	add_child(obj)
	var h = hex(loc)
	obj.set_hex(h)
	obj.set_dir(dir)
	h.set_object(obj)

func add_hex(loc):
	var hex = hex_scene.instantiate()
	hex.loc = loc.clone()
	hexes[loc.key] = hex
	add_child(hex)
	return hex

# Convert a hex loc to a screen pos vector
func loc_to_pos(loc):
	var x = hex_radius * (loc.q * SQRT3 + loc.r * SQRT3 / 2)
	var y = hex_radius * (loc.r * 3.0 / 2)
	return Vector2(x,y)

# Get a given hex node from a location, or null if none
func hex(loc):
	if loc is HexNode:
		return loc
	return hexes.get(loc.key)

# Apply the provided function to all hexes on the map
func each_hex(fn: Callable):
	for hex in hexes.values():
		fn.call(hex)

# Given a hex, return an array of all hexes next to that hex
func neighbors(hex):
	var loc = HexLoc.new(0,0)
	var neighbors = []
	for dir in HexDir.ALL_DIRS:
		loc.update(hex.loc)
		loc.offset_dir(dir)
		var neighbor = hex(loc)
		if neighbor:
			neighbors.append(neighbor)
	return neighbors

# Get array of reachable tiles from a given starting hex, within maxMove
# steps
func reachable_tiles(start_loc, max_cost, hex_cost = 1):
	var start_hex = hex(start_loc)

	# Reset the state of all nodes in the map
	for hex in hexes.values():
		# We support constant, callable calculation, and "don't" as cost options
		if is_same(hex_cost, false):
			# Don't recalc costs
			pass
		elif hex_cost is Callable:
			# Let caller recalc costs by hex inspection
			hex.search_cost = hex_cost.call(hex)
		else:
			# Constant cost
			hex.search_cost = hex_cost
		# Initial best cost is <terrible>, so any shorter path will be chosen
		hex.search_best_cost = 100000.0
		# Ref to best prior node found
		hex.search_best_prior = null

	# Init our search state in our starting hex to the appropriate values
	start_hex.search_best_cost = 0.0

	# Process our list, working outwards from the starting location
	var loc = HexLoc.new(0,0)
	var test_list = [start_hex]
	while test_list.size() > 0:
		# Get next location to test
		var test_hex = test_list.pop_front()
		var test_cost = test_hex.search_best_cost
		# Check all 6 directions
		for dir in HexDir.ALL_DIRS:
			# Just kidding, skip the one we came from, as it will obviously not be
			# faster to hit the same hex twice...
			if dir != HexDir.add(test_hex.search_best_dir, 3):
				# Find the hex in the map
				loc.update(test_hex.loc)
				loc.offset_dir(dir)
				var neighbor = hex(loc)
				# Calc the new total cost
				var new_cost = test_cost + neighbor.search_cost
				# Is this the best way we've found to this hex?
				if new_cost < neighbor.search_best_cost && new_cost <= max_cost:
					# Yep! Update our search vals
					neighbor.search_best_cost = new_cost
					neighbor.search_best_prior = test_hex
					# And check its neighbors next
					test_list.append(neighbor)

# Find the shortest path between two locations, biased towards straight line
# movement and with an optional initial starting bias.  Basically a modified
# A* algorithm with weighting on direction.  Pass in a cost function to calculate
# the cost of entering a given hex, to allow avoiding hazards or hexes (impassible, etc)
#
# {
#   cost: <false, int, fn(hex)> - cost for a given hex, false for "don't update"
#   max_cost: <float> - once we hit this cost, stop checking
#   start_dir: <HexDir> -
# }
func shortest_path(start_loc, end_loc, opts = {}):
	var start_hex = hex(start_loc)
	var end_hex = hex(end_loc)

	# Unpack our options
	var start_dir = opts.get('start_dir', HexDir.RIGHT)
	var hex_cost = opts.get('cost', 1)
	var max_cost = opts.get('max_cost', 100000.0)
	var max_test_cost = max_cost + 2.0 # Fudge factor to deal with direction bias

	# Reset the state of all nodes in the map
	for hex in hexes.values():
		# We support constant, callable calculation, and "don't" as cost options
		if is_same(hex_cost, false):
			# Don't recalc costs
			pass
		elif hex_cost is Callable:
			# Let caller recalc costs by hex inspection
			hex.search_cost = hex_cost.call(hex)
		else:
			# Constant cost
			hex.search_cost = hex_cost
		# Initial best cost is <terrible>, so any shorter path will be chosen
		hex.search_best_cost = 100000.0
		# Ref to best prior node found
		hex.search_best_prior = null
		# Dir we entered facing, in best-to-date path
		hex.search_best_dir = null

	# Init our search state in our starting hex to the appropriate values
	start_hex.search_best_cost = 0.0
	start_hex.search_best_dir = start_dir

	# Process our list, working outwards from the starting location
	var loc = HexLoc.new(0,0)
	var test_list = [start_hex]
	while test_list.size() > 0:
		# Get next location to test
		var test_hex = test_list.pop_front()
		var test_cost = test_hex.search_best_cost
		# Check all 6 directions
		for dir in HexDir.ALL_DIRS:
			# Just kidding, skip the one we came from, as it will obviously not be
			# faster to hit the same hex twice...
			if dir != HexDir.add(test_hex.search_best_dir, 3):
				# Find the hex in the map
				loc.update(test_hex.loc)
				loc.offset_dir(dir)
				var neighbor = hex(loc)
				# Calc the new total cost
				var new_cost = test_cost + neighbor.search_cost
				if dir != test_hex.search_best_dir:
					new_cost += 0.01
				# Is this the best way we've found to this hex?
				if new_cost < neighbor.search_best_cost:
					# Yep! Update our search vals
					neighbor.search_best_cost = new_cost
					neighbor.search_best_dir = dir
					neighbor.search_best_prior = test_hex
					# And add to our test list unless we're at max cost - short circuit
					# here saves a LOT of testing if we know we're only allowed to move a
					# certain distance...
					if new_cost < max_test_cost:
						test_list.append(neighbor)

		# Check our target hex to see if we found a path
		if end_hex.search_best_prior != null:
			# Got one, rebuild it and return it
			var path = [];
			var cursor = end_hex
			var summary = ""
			while (cursor):
				summary += cursor.loc.label() + " => "
				path.unshift(cursor)
				cursor = cursor.search_best_prior
			print(summary)
			return path

		else:
			print('No path found!')
			return null
