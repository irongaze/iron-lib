# Represents a location in a hex grid.  Uses q/r/s cubic coordinates.  Check out
# this link for info on math: https://www.redblobgames.com/grids/hexagons/
class_name HexLoc extends Resource

# Our state
var q: int
var r: int
var s: int
var key: int

# Constructor
func _init(nq, nr):
	update(nq, nr)

# For debug, output a nice clean string rep
func label():
	return 'hex[%s,%s]' % [q, r]

# Clone a location
func clone():
	return HexLoc.new(q, r)

# Update a location's coordinates
func update(nq, nr = null):
	if nq is HexLoc:
		r = nq.r
		q = nq.q
	else:
		q = nq
		r = nr
	s = -q - r
	key = q * 1000 + r

# Convert to x,y vector
func to_xy():
	var x = q * sqrt(3) + r * sqrt(3) / 2
	var y = r * 3.0 / 2
	return Vector2(x,y)

# Num hexes to a given loc
func distance_to(loc):
	return (abs(q - loc.q) + abs(r - loc.r) + abs(s - loc.s)) / 2

# Return the direction to a given location
func dir_to(loc):
	var rot = to_xy().angle_to_point(loc.to_xy())
	rot = rad_to_deg(rot)
#	print(loc.label())
#	print(to_xy())
#	print(loc.to_xy())
#	print(rot)

# Offset location in a given direction
func offset_dir(dir, steps = 1):
	HexDir.offset_loc(self, dir, steps)
