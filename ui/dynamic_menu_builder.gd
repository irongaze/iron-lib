class_name DynamicMenuBuilder extends RefCounted

var menu : DynamicMenu = null
var node : PopupMenu = null


func _init(parent: DynamicMenu):
  menu = parent
  reset()


func get_node():
  return node


func reset():
  # Delete existing menu, if any
  if node != null:
    if node.parent != null: node.parent.remove_child(node)
    node.queue_free()

  # Create new menu to manage
  node = PopupMenu.new()


func add_item(key, label):
  var id = menu._add_key(key)
  node.add_item(label, id)


func add_submenu_item(key, label):
  var id = menu._add_key(key)
  var submenu_name = "DynamicSubmenu" + str(id)
  node.add_submenu_item(label, submenu_name, id)



