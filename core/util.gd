    # Collection of general purpose utility functions.
@tool
class_name Util extends RefCounted


# Safely get an index in an array, with a default value if
# out of range or null value at index.
static func array_get(arr, index, def_val = null):
  if index >= 0 && index < arr.size():
    var val = arr[index]
    if val != null:
      return val
  return def_val


static func float_to_vector(val):
  return Vector2(val, val)


# Convert a regex pattern with pre/post '/' chars into
# a compilte RegEx instance.  Helper to fake native regex support...
static func to_regex(pattern: String):
  # Remove /.../ delims
  assert(pattern[0] == "/")
  assert(pattern[pattern.length()-1] == "/")
  pattern = pattern.substr(1, pattern.length() - 2)

  # Compile & return regex
  var regex = RegEx.new()
  regex.compile(pattern)
  return regex


static func matches(pattern: String, str: String):
  var regex = to_regex(pattern)
  return null != regex.search(str)


static func extract(pattern: String, str: String):
  var regex = to_regex(pattern)
  var matches = regex.search(str)

  match matches.get_group_count():
    0:
      return matches.get_string(0)
    1:
      return matches.get_string(1)
    _:
      return matches.strings.slice(1)


static func replace(pattern: String, str: String, new_str: String):
  var regex = to_regex(pattern)
  return regex.sub(str, new_str)


static func replace_all(pattern: String, str: String, new_str: String):
  var regex = to_regex(pattern)
  return regex.sub(str, new_str, true)


# Return a new array containing all items from passed array where
# passed filter function returned true
static func filter(array: Array, fn: Callable):
  var res = []
  for x in array:
    if fn.call(x):
      res.append(x)
  return res


static func is_numeric(val):
  if typeof(val) == TYPE_INT: return true
  if typeof(val) == TYPE_STRING:
    return matches("/^-?[1-9][0-9]*$/", val)
  return false
