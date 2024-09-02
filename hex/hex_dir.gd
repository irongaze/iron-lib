# Hex maps have 6 possible directions an item can face. This class
# manages working with those directions.
class_name HexDir extends Resource

# Constants for directions for clearer code
const RIGHT = 0
const DOWNRIGHT = 1
const DOWNLEFT = 2
const LEFT = 3
const UPLEFT = 4
const UPRIGHT = 5

# Map from dir # to q+r offsets
const MAP = [
	[1,0], [0,1], [-1,1], [-1,0], [0,-1], [1,-1]
]

# Instead of doing lots of range(6) calls everywhere, give us a const
const ALL_DIRS = [0,1,2,3,4,5]

static func add(dir, amt = 1):
	dir += amt
	return dir % 6

static func sub(dir, amt = 1):
	dir -= amt
	return dir % 6

# Convert dir to a screen-normalized rotation in degrees
static func to_rotation(dir):
	dir %= 6
	return dir * 60

# Convert dir to a unit vector pointing along that dir
static func to_vector(dir):
	var v = Vector2(0, 1.0)
	v.rotate(to_rotation(dir))
	return v

static func offset_loc(loc, dir, steps = 1):
	dir %= 6
	var q = loc.q + MAP[dir][0] * steps
	var r = loc.r + MAP[dir][1] * steps
	loc.update(q, r)
