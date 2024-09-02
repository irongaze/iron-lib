# Thin proxy for our main Data object, allowing operations on a subset of the full
# data tree.
@tool
class_name DataCursor extends RefCounted

# Variables
var data: Data
var key: String

func _init(ndata: Data, nkey: String):
  data = ndata
  key = nkey

func _to_string():
  return "DataCursor<" + key + ">"

# Convert a "local" key to a "global" key based at the data root
func full_key(nkey):
  return Data.join_path([key, nkey])

# Core API
@warning_ignore("native_method_override")
func set_val(nkey, value, return_cursor = false):
  return data.set_val(full_key(nkey), value, return_cursor)

func set_all(key_val_map):
    # Do our own looping to expand keys
    for k in key_val_map:
      set(k, key_val_map[k])

@warning_ignore("native_method_override")
func get_val(nkey, default = "__missing__"):
  return data.get_val(full_key(nkey), default)

func get_all(nkey):
  return data.get_all(full_key(nkey))

func count_all(nkey):
  return data.count_all(full_key(nkey))

func has(nkey):
  return data.has(full_key(nkey))

func unset(nkey):
  return data.unset(full_key(nkey))

#func load(nkey, model, key_map = null):
  #return data.load(full_key(nkey), model, key_map)

func cursor(nkey = ""):
  return data.cursor(full_key(nkey))

func keys(nkey = "", full = false):
  # Proxy as usual
  var keys = data.keys(full_key(nkey), full)
  # If returning full keys, make them relative to our root, not the global root
  if full:
    keys = keys.map(func(k): return k.replace(key, "").lstrip("."))
  return keys

func count(nkey = ""):
  return data.count(full_key(nkey))

# Export
func to_json(key = "", pretty_print = false):
  if key is bool:
    pretty_print = key
    key = ""
  return data.to_json(full_key(key), pretty_print)

func to_data():
  return data.to_array(key, [])
