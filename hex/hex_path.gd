# A path along a series of hex locs, with utilities for movement and tesselation
# for drawing.
class_name HexPath extends Resource

signal path_changed()

# Map we're a path on
var map: HexMap
# Locations the path traverses
var locs: Array[HexLoc]
var dirs: Array[int]
# The Curve2D we use for interpolation and splining
var curve:= Curve2D.new()
var curve_dirty:= true
# Traversal support
var traversal_time = 0.0
var traversal_speed = 1.0
var traversal_index = 0

# Pass in the map we're bound to, needed for location conversion
func _init(new_map: HexMap):
	map = new_map
	reset()

func size():
	return locs.size()

func is_empty():
	return size() <= 1

# Reset path's locations list
func reset():
	locs = []
	dirs = []
	curve_dirty = true
	path_changed.emit()

# Append a location
func add_loc(loc: HexLoc):
	var prior_loc = locs.back()
	locs.append(loc)
	if prior_loc == null:
		dirs.append(HexDir.RIGHT)
	else:
		dirs.append(prior_loc.dir_to(loc))

	# We need a curve rebuild, and let anyone watching us know we changed
	curve_dirty = true
	path_changed.emit()

# Convert this path into a series of pixel-based points for
# drawing.  Pass smooth = true for a spline-based smoothing, false for
# linear center-to-center points.
func to_points(smooth = true):
	if smooth:
		# Rebuild if needed
		rebuild_curve()
		# Tesselate into points & return 'em
		return curve.tessellate()
	else:
		# Just build point list from hex centers
		var points = []
		for i in range(0, locs.size()):
			points.append(map.loc_to_pos(locs[i]))
		return points

func start_traverse(hexes_per_sec = 1.0):
	traversal_time = 0.0
	traversal_speed = hexes_per_sec
	traversal_index = 0

# Pass an object and a time delta to move the object along the path.
# Returns true once traversal is complete.
# TODO: callback for hitting each loc along the way?
func traverse(delta: float, obj: HexObject):
	# We need our curve
	rebuild_curve()

	# Calc percent completed
	traversal_time += delta
	var maxlen = curve.get_baked_length()
	var percent = traversal_time * traversal_speed / size()

	# Get transform along path
	var done = false
	var index
	var transform
	if percent < 1.0:
		# Not yet done, update passed object's position along our path
		# Ease in/out to avoid jumpiness
		percent = Tween.interpolate_value(0.0, 1.0, percent, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		index = floorf(percent * (locs.size() - 1))
		transform = curve.sample_baked_with_rotation(percent * maxlen, true)
	else:
		# Traversal complete!
		index = locs.size() - 1
		transform = curve.sample_baked_with_rotation(maxlen, true)
		done = true

	# Apply transform to object
	obj.position = transform.get_origin()
	obj.rotation = transform.get_rotation()

	# Update object loc and dir if needed
	if index > traversal_index:
		traversal_index = index
#		obj.set_dir(dirs[index], false)
#		obj.set_loc(locs[index], false)

	# Any more to do?
	return done

# Return a smoothed path
func rebuild_curve():
	# Only do this when necessary
	if !curve_dirty: return

	# Need to rebuild, start by clearing curve
	curve.clear_points()

	# Sanity check
	if locs.size() <= 1: return []

	# Set up
	var firstLoc = locs[0]
	var lastLoc = locs[-1]

	# Add first point to curve
	var old_pos: Vector2
	var new_pos = map.loc_to_pos(firstLoc)
	curve.add_point(new_pos, Vector2(0,0), Vector2(0,0))

	# Build point list
	for i in range(1, locs.size()):
		# Each point is the mid-point between two hex centers
		old_pos = new_pos
		new_pos = map.loc_to_pos(locs[i])
		var pt = old_pos.lerp(new_pos, 0.5)
		# Control points aim towards old and new centers, weighted to give a nice curve
		var ctrl = pt.direction_to(old_pos).normalized() * map.hex_radius * 0.7
		# And add it to the curve
		curve.add_point(pt, ctrl, ctrl.rotated(PI))

	# Add final point
	curve.add_point(map.loc_to_pos(lastLoc), Vector2(0,0), Vector2(0,0))

	# And we're rebuilt!
	curve_dirty = false
