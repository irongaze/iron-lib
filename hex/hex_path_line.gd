# Utility node for drawing hex paths
class_name HexPathLine extends Line2D

# Path we draw
var path: HexPath = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_path(new_path):
	# Disconnect our listener on old path
	if path != null:
		path.path_changed.disconnect(update_points)

	# Store new path
	path = new_path
	# Connect if path is present
	if path != null:
		path.path_changed.connect(update_points)

	# And update our points from new path
	update_points()

func update_points():
	# Reset our points
	clear_points()

	# If no bound path, we're done
	if path == null: return

	# Otherwise, update
	var points = path.to_points()
	for point in points:
		add_point(point)
