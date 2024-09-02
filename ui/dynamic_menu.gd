class_name DynamicMenu extends DynamicMenuBuilder

# Fired when the item with the given key is selected
signal key_selected(key)


# Map from ID to key
var key_map := {}
var parent : Node = null
var next_id : int


func _init(node: Node):
  parent = node
  reset()


func reset():
  # Delete existing menu, if any
  super()

  # Reset our internal state
  key_map = {}
  next_id = 100

  # Bind to new menu node created by our base class
  node.id_pressed.connect(func(id): _id_pressed(id))


func _id_pressed(id):
  print("ID pressed: " + str(id))
  var key = key_map[id]
  key_selected.emit(key)


func _add_key(key):
  var id = next_id
  next_id += 1
  key_map[id] = key
  return id


func on_select(fn: Callable):
  key_selected.connect(fn)


func popup_context(parent : Node):
  parent.get_tree().root.add_child(node)
  node.set_position(DisplayServer.mouse_get_position())
  node.popup()
