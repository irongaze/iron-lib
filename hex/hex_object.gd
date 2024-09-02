# Base class for an object that can live in a hex
class_name HexObject extends Node2D

# Direction we're facing
@export var dir: int = HexDir.RIGHT

# What type of object we are, expected to be an Enum
var object_type: int = 0

# The map that owns us
var map: HexMap
# Hex we live in
var hex: HexNode

func _enter_tree():
	update_pos()
	update_dir()

func set_loc(new_loc: HexLoc, update = true):
	var new_hex = map.hex(new_loc)
	set_hex(new_hex, update)

# Set the hex we're in, and optionally update our position
func set_hex(new_hex: HexNode, update = true):
	hex = new_hex
	if update:
		position = hex.position

# Set the direction we're facing, and optionally update our rotation
func set_dir(new_dir: int, update = true):
	dir = new_dir
	if update:
		update_dir()

func update_dir():
	print("Update dir: %s" % dir)
	rotation_degrees = HexDir.to_rotation(dir)

func update_pos():
	if hex: position = hex.position
