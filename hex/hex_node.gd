# Represents a single hex in a hex map.  Low-level, re-usable script
# that can be extended in different games.
class_name HexNode extends Node2D

# Our owning map
@onready var map: HexMap = get_parent()
# Our location on the map in q+r format
@export var loc: HexLoc
@export var highlight: Sprite2D

# HexObject's by type
var objects: Dictionary = {}
# Enum flags
var flags = []
# Our highlight status
var highlight_map: Dictionary = {}

# Search variables - we store these in the nodes themselves to
# avoid allocations on every search, and to allow pre-calculation
# of shared weightings as an optimization
var search_cost: float
var search_best_prior: HexNode
var search_best_cost: int
var search_best_dir: int

# Constructor
func _init(init_loc = null):
	if init_loc:
		loc = init_loc
	pass

# Set our position on screen based on our logical location
func _ready():
	# Set our position in the map
	position = map.loc_to_pos(loc)
	$Label.set_text(loc.label())

	# Add our click target
	var area = Area2D.new()
	add_child(area)
	var shape = CollisionPolygon2D.new()
	area.add_child(shape)

	# Build collision shape's polygon
	var v = Vector2(0, -map.hex_radius)
	var vertices = []
	for i in range(6):
		vertices.append(Vector2(v.x, v.y))
		v = v.rotated(deg_to_rad(60))
	shape.set_polygon(PackedVector2Array(vertices))

	# Bind to relevant signals
	area.mouse_entered.connect(on_mouse_enter)
	area.mouse_exited.connect(on_mouse_exit)
	area.input_event.connect(on_input)

func set_highlight(color: Color, priority: int = 0):
	highlight_map[priority] = color
	update_highlight()

func remove_highlight(priority: int = 0):
	highlight_map.erase(priority)
	update_highlight()

# Apply highest-priority highlight tint to our highlight sprite
func update_highlight():
	var highest = -1
	var color = null
	for priority in highlight_map:
		if priority > highest:
			highest = priority
			color = highlight_map[priority]

	if color == null:
		highlight.visible = false
	else:
		highlight.visible = true
		highlight.modulate = color

func on_mouse_enter():
	map.hex_hover.emit(self, true)

func on_mouse_exit():
	map.hex_hover.emit(self, false)

func on_input(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		map.hex_clicked.emit(self, event.button_index, event.pressed)

func neighbors():
	return map.neighbors(self)

func get_object(type: int):
	return objects.get(type)

func set_object(obj):
	objects[obj.object_type] = obj

func has_object(type):
	return objects.get(type) != null

