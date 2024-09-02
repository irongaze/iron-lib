@tool
class_name Data extends RefCounted

# Class for dealing with unstructured or minimally structured data.
#
# Basic usage:
#
#   var data = Data.new([<json string|Dictionary|Data>])
#
#   # Basic key/values
#   data.set_val('key', 'value')
#   data.has_val('key')
#    => true
#   data.get_val('key')
#    => 'value'
#
#   # Implicitly created hierarchy
#   data.set_val('user.name', 'Bob')
#   data.get_val('user.name')
#    => 'Bob'
#
#   # Default value for missing keys
#   data.get_val('user.missing', 'what???')
#    => 'what???'
#
#   # Array access - append
#   data.set_val('log.errors[]', 'Missing armor')
#   data.get_val('log.errors[0]')
#    => 'Missing armor'
#
#   # Access keys
#   data.set_val('a.b', 1)
#   data.set_val('a.c', 2)
#   data.keys('a')
#    => ['b', 'c']
#   data.keys('a', true)
#    => ['a.b', 'a.c']
#   # And count the values too
#   data.count('a')
#    => 2
#

# Our state
var root_node: Dictionary
var read_only: bool


# Helper function to concat an array of path keys and indices into a single
# full text key.
static func join_path(path: Array):
  var str = ""
  for index in path:
    if index == null:
      index = '[]'
    elif index is int:
      index = '[' + str(index) + ']'

    assert(index is String)
    if index.begins_with('['):
      str += index
    elif index.length() > 0:
      if str.length() > 0: str += '.'
      str += index

  return str


# Create a new data object, with optional initialization.
func _init(new_data = null):
  # By default, raise errors
  read_only = false

  if new_data == null:
    # Start empty
    root_node = {}

  else:
    if new_data is String:
      # Assume a json string, attempt to decode, ensure root val is a hashed type (not an [...] array)
      var json = JSON.parse_string(new_data)
      if new_data.begins_with('{') && json is Dictionary:
        root_node = json
      else:
        assert(false, 'Invalid initialization JSON string for Data: ' + new_data)
        root_node = {}

    elif new_data is Dictionary:
      if validate_value('', new_data):
        root_node = expand_value(new_data)
      else:
        assert(false, 'Invalid initialization object for Data: ' + JSON.stringify(new_data))
        root_node = {}

    else:
      # WTF
      assert(false, 'Invalid initialization value for Data: ' + JSON.stringify(new_data))
      root_node = {}


func _to_string():
  return "Data<" + to_json() + ">"


func set_read_only():
  read_only = true


# Sets a value at a given key, creating intermediate nodes as needed.  If return_cursor
# is true, return a cursor at the newly created key, useful for adding values onto
# a node created with [] array appending.
func set_val(key, value, return_cursor = false):
  # Validate key & value
  if !validate_settable(): return false
  if !validate_key(key): return false
  if !validate_value(key, value): return false

  # Split out indices
  var path = tokenize(key)
  # Find final node, creating path as needed (and expand any [] into [n])
  var node = ensure_index(path)

  # What's our final index?
  var index = path.back()

  # Nope.
  assert(not index is DataFilter, 'Filters are not supported when modifying Datas')

  # Expand nested data (e.g. Data instances and other objects)
  value = expand_value(value)

  # Now, set the damn thing
  if Util.is_numeric(index):
    # For numeric indices, ensure the node array is large enough
    index = int(index)
    if node.size() <= index:
      var i = node.size()
      while i <= index:
        node.append(null)
        i += 1

    # And set!
    node[index] = value

  else:
    # Hash key indices just get set
    node[index] = value

  # If a cursor has been requested, return one
  if return_cursor:
    return DataCursor.new(self, Data.join_path(path))
  else:
    return true


func set_all(key_val_map):
  for k in key_val_map:
    set_val(k, key_val_map[k])


# Helper function to take objects implementing to_data()
# and expand them, recursively.  Returns a full nested object.
func expand_value(val):
  if val is Object && val.has_method('to_data'):
    val = val.to_data()

  if val is Array:
    val = val.map(expand_value)

  elif val is Dictionary:
    for k in val.keys():
      val[k] = expand_value(val[k])

  return val


# True if given object is either an array or a hash
func is_container(node):
  return typeof(node) == TYPE_ARRAY || typeof(node) == TYPE_DICTIONARY


func container_has(node, index):
  if node is Array:
    return index is int && index >= 0 && index < node.size()
  else:
    return index is String && node.has(index)


# Walk the given index path, creating nodes along the way as needed,
# and return a reference to the final node.  Expands [] into [n] as appropriate
# in passed in indices array.
func ensure_index(indices):
  var node = root_node
  var i = 0
  while i < indices.size() - 1:
    # Get next index to process
    var index = indices[i]
    # We don't support filters in set-alikes
    if index is DataFilter:
      assert(false, 'Filters are not supported when modifying Datas')

    # A null index here indicates that we should append to the current array,
    # so figure out what index it should be
    if index == null:
      assert(node is Array, 'Attempt to set with numeric index into dictionary node: ' + JSON.stringify(indices))
      index = node.size()
      indices[i] = index

    # Get the next node in the chain
    if container_has(node, index) && node[index] != null:
      # Existing index, move cursor to next node
      node = node[index]
      # Validate it - must be an array/hash and not a leaf value
      assert(node && is_container(node), 'Mis-matched node type in Data while building key path')

    else:
      # Missing index, create new container.  First, peek ahead to see what kind of
      # container we need.  Array if numeric/null, hash if string
      var container = []
      if indices[i+1] is String: container = {}

      # For numeric indices, ensure the node array is large enough
      if Util.is_numeric(index):
        var j = node.size()
        while j <= index:
          node.append(null)
          j += 1

      # Add the container at the index
      node[index] = container
      # Now move cursor
      node = container

    # Iterate
    i += 1

  # If the last index is null, we need to expand it before returning
  if indices[i] == null:
    indices[i] = node.size()

  return node


# Returns the value at key, if not found return defVal.  If key points to
# an internal node (i.e. not a value), return a cursor to that node.
func get_val(key, def_val = "__missing__"):
  if !validate_key(key): return null

  # Expand the path
  var path = tokenize(key)
  var expanded = expand_path(path)
  var keys = expanded[0]
  var vals = expanded[1]

  # Expecting exactly one match
  var val
  if keys.size() == 1:
    # Got one match, get it and the expanded path
    key = keys[0]
    val = vals[0]
    # Nope!  Have an actual value, convert to cursor if needed & return
    if is_container(val):
      val = DataCursor.new(self, key)
    return val

  elif keys.size() > 1:
    assert(false, 'Multiple values found in Data get: ' + key)
    return null

  # Zero matches or explicit null value... return default or throw error
  if def_val is String && def_val == "__missing__":
    # No default provided => error
    assert(false, 'Missing required value in Data: ' + key)
    return null

  else:
    # Return our default
    return def_val


# Same as get_val(), but returns array of all found results.
func get_all(key):
  # Bad key == suck
  if !validate_key(key):
    return []

  # Get all leaf values and nodes for this key, expanded
  var path = tokenize(key)
  var expanded = expand_path(path)
  var keys = expanded[0]
  var vals = expanded[1]

  # Convert to final format
  var list = []
  for i in range(keys.size()):
    var k = keys[i]
    var v = vals[i]
    if is_container(v):
      v = DataCursor.new(self, k)
    list.append(v)

  return list


func count_all(key):
  return get_all(key).size()


# Walk the tree for a given set of indices, returning the specified
# node, or null if invalid/missing key.
func get_node(path):
  # Start at root
  var expanded = expand_path(path)
  var vals = expanded[1]
  if vals.size() == 1:
    return vals[0]
  else:
    return null


# Given a path array and optional starting node+key, walk the path
# expanding any filters as you go.  Returns hash of {key = node}
func expand_path(path, start_node = null, start_path = null):
  # Start at specified node if provided, otherwise start at root
  var nodes
  var keys
  if start_node:
    nodes = [start_node]
    keys = [start_path]
  else:
    nodes = [root_node]
    keys = ['']

  # Run each index in the path
  for index in path:
    # Get traversal doesn't support [] - fail out
    if index == null:
      return [[], []]

    # At each step in the path, expand all existing nodes, build new list (tracking growing key for each)
    var new_nodes = []
    var new_keys = []
    for n in range(nodes.size()):
      var cur_node = nodes[n]
      var cur_key = keys[n]
      # Got the node, now handle traversing the index
      if index is DataFilter:
        # This index is a filter instead of a specific numeric index or string key,
        # so we need to look ahead for each index and see if we pass, add to list if so.
        if cur_node is Array:
          for i in range(cur_node.size()):
            var new_node = cur_node[i]
            var new_key = Data.join_path([cur_key, i])
            # Test filter
            if index.test(new_node, new_key):
              # Add if passes, store array index we're on to key
              new_nodes.append(new_node)
              new_keys.append(new_key)

        else:
          # Wtf.  Drop the node.
          pass

      elif is_container(cur_node) && container_has(cur_node, index):
        # Numeric or string index = keep walking list
        new_nodes.append(cur_node[index])
        new_keys.append(Data.join_path([cur_key, index]))

      else:
        # Got to a leaf or missing index, stop expanding this path
        pass

    # Prep for next index, repeat with new list of nodes
    nodes = new_nodes
    keys = new_keys

  # Once we're here, we have the final array of nodes, return 'em
  return [keys, nodes]


# Return true if there is a non-null, non-empty-string node or value at the given key
func has_val(key):
  if !validate_key(key): return false

  var val = get_val(key, "--NOPE--")
  return val != "--NOPE--" && val != null && val != ""


# Remove a node/value from the tree
func unset(key):
  if !validate_settable(): return
  if !validate_key(key): return

  # Tokenize, then remove & save last index
  var path = tokenize(key)
  var last = path.pop_back()
  if last == null:
    return

  var node = get_node(path)
  if node is Array:
    # Shorten array if removing last item, otherwise null out
    if last == node.size() - 1:
      node.pop_back()
    else:
      node[last] = null
    return

  elif node is Dictionary:
    # Just delete the key
    var removed = node.has(last)
    node.erase(last)
    return

  else:
    # Not present...
    return


# Return a cursor at the given key.
func cursor(key = ''):
  var val = get_val(key, null)
  if val is DataCursor:
    return val
  else:
    return null


# Returns an array of keys for a given path, or [] if none.  For arrays, returns
# indexes with non-empty values.
func keys(key = '', full = false):
  # Ensure key is well-formed
  if !validate_key(key): return []

  var keys = []
  var path = tokenize(key)
  var node = get_node(path)
  if is_container(node):
    # Got a container!
    if node is Array:
      # Only return keys with values
      for sub_key in range(node.size()):
        if node[sub_key] != null:
          keys.append('[' + str(sub_key) + ']')

    else:
      # Dictionary
      keys = node.keys()

    # Expand to full keys if desired
    if full && key.length() > 0:
      for i in range(keys.size()):
        keys[i] = Data.join_path([key, keys[i]])

  return keys


# Return the number of elements at the given level of the tree.
func count(key = ''):
  var keys = keys(key)
  return keys.size()


# Tokenize helper to process the '[...]' part of a key.
func tokenize_brackets(key):
  if key == '': return [[],'']

  var escaped = false
  var count = 0
  var body = null
  var suffix = null
  var token
  for i in key.length():
    var char = key[i]
    if char == '[':
      # New opening bracket, if not escaped
      if !escaped: count += 1
      escaped = false

    elif char == ']':
      # New closing bracket, if not escaped
      if !escaped: count -= 1
      escaped = false

      # If our bracket count = 0, we're done!
      if count == 0:
        # Done, found final bracket!
        body = key.substr(1, i - 1)
        suffix = key.substr(i + 1)
        break

    elif char == '\\':
      # New escape sequence, if not itself escaped
      if !escaped:
        escaped = true

  if body == '':
    # Empty brackets = null index
    token = null
  elif body.is_valid_int():
    # Int index
    assert(Util.matches("/^(0|[1-9][0-9]*)$/", body), "Invalid nested data key - invalid numeric array index: " + body)
    token = int(body)
  elif body == '*':
    # Star index = "pass all" filter
    token = DataFilter.new(self, [], '*', null)
  else:
    # Gotta be a full filter...
    var parts = tokenize_key(body)
    var path = parts[0]
    var suffixParts = Util.extract("/^([!=><]+)(.*)$/", parts[1])
    var op = suffixParts[0]
    var value = suffixParts[1]
    token = DataFilter.new(self, path, op, value)
    assert(token.is_valid(), "Invalid nested data key - incomplete or malformed array filter: " + body)

  # Handle trailing '.' when tokenizing remaining key text
  if suffix.begins_with('.'):
    suffix = suffix.substr(1)

  # Take our remaining suffix and parse *it*
  var suffixParts = tokenize_key(suffix)
  var suffixTokens = suffixParts[0]
  var suffixSuffix = suffixParts[1]

  # Return our new array index token + any remaining suffix tokens
  var tokens = [token]
  tokens.append_array(suffixTokens)
  return [tokens, suffixSuffix]


# Helper to pull off the valid key that starts the key string, and return it tokenized, then
# return any remaining suffix (when valid, an operator + value e.g. '>=5').
func tokenize_key(key):
  if !key: return [[],'']

  # Get prefix
  var parts = Util.extract("/[a-zA-Z0-9\\.]*/", key)
  var remainder = key.substr(parts.length())

  # Split the parts
  if parts:
    # Validate parts
    assert(!parts.begins_with('.') && !parts.ends_with('.') && !parts.contains('..'), "Invalid nested data key - multiple dereference: " + key)
    # Split non-bracket stuff
    parts = parts.split('.', false)
  else:
    parts = []

  # Run 'em and aggregate into tokens
  var tokens = []
  for part in parts:
    # Add the string key if any
    if part.length() > 0:
      tokens.append(part)

  var suffix = remainder
  if remainder:
    # Is remainder brackets?  If so, parse that shit
    if remainder.begins_with('['):
      parts = tokenize_brackets(remainder)
      tokens.append_array(parts[0])
      suffix = parts[1]

  return [tokens, suffix]


# Split a key into its parts, e.g. 'foo.bar[2]' => ['foo', 'bar', 2]
func tokenize(key):
  # Tokenize a key and get any remainder
  var parts = tokenize_key(key)

  # Validate that we don't have a remainder
  if parts[1].length() > 0:
    assert(false, 'Invalid Data key - unexpected remainder: ' + parts[1])
    return null

  return parts[0]


# Call before modifying the underlying data to
# prevent changing a read-only data set.
func validate_settable():
  if read_only:
    assert(false, 'Attempt to modify read-only Data')
    return false

  return true


# Validate the *format* of a key, meaning well-formedness, NOT
# presence in the tree.
func validate_key(key):
  # Keys have to be strings, duh
  if not key is String:
    assert(false, 'Non-string Data key: ' + JSON.stringify(key))
    return false

  # Prevent root-level numeric key array ('[1].bob')
  if key.begins_with('['):
    assert(false, 'Root arrays are not allowed in Data: ' + key)
    return false

  # OK, tokenize, see if we get any exceptions trying to parse e.g. filters, or a..b or whatever
  var path = tokenize(key)
  if path == null:
    return false

  # Now, validate all path indices
  for el in path:
    if el is String:
      if !Util.matches("/^[a-zA-Z][a-zA-Z0-9]*$/", el):
        assert(false, 'Invalid nested data key - invalid hash key: ' + el)
        return false

  return true


# Call to ensure that a passed value is of a valid type - must be a valid simple type,
# an object that implements to_data, or an array/hash containing those things.
func validate_value(key, val):
  if val is Array:
    # Container values need to only contain valid child values, and must contain valid keys
    for sub_key in range(val.size()):
        # Validate child key & value
        var sub_val = val[sub_key]
        var full_key = Data.join_path([key, sub_key])
        if !validate_key(full_key) || !validate_value(full_key, sub_val):
          return false

    return true

  if val is Dictionary:
    # Dictionaries need to only contain valid child values, and must contain valid keys
    for sub_key in val.keys():
        var sub_val = val[sub_key]
        if sub_key is int:
          assert(false, 'Numeric key in dictionary in Data: ' + JSON.stringify(val))
          return false

        # Append key to root string
        var full_key = Data.join_path([key, sub_key])
        if !validate_key(full_key) || !validate_value(full_key, sub_val):
          return false

    return true

  elif val is Object && val.has_method('to_data'):
    # Objects must implement to_data() to be valid
    if val.to_data:
      var sub_data = val.to_data()
      if validate_value(key, sub_data):
        return true

    assert(false, 'Invalid value in Data: ' + JSON.stringify(val))
    return false

  else:
    # Leaf values can only be these types
    var valid = val == null || val is bool || val is int || val is String
    if !valid:
      assert(false, 'Invalid value in Data: ' + JSON.stringify(val))

    return valid


# Return this data object as a JSON string, optionally sub-setting by node
# key, and optionally pretty-printing for easier display.
#
#   data.to_json() => full tree, single line
#   data.to_json(true) => full tree, pretty print
#   data.to_json('client[0]', false) => sub tree, single line
#
func to_json(key = '', pretty_print = false):
  if key is bool:
    pretty_print = key
    key = ''

  var path = tokenize(key)
  var node = get_node(path)

  if node != null:
    return JSON.stringify(node, "\t" if pretty_print else "")
  else:
    return null


# We can convert to an array suitable for nested data usage... since we are one.  :-)
func to_data(key = ""):
  var path = tokenize(key)
  var node = get_node(path)
  if node == null:
    return null
  else:
    return clone_node(node)


# Deep-copy return values to some of our functions.
func clone_node(node):
  return node.duplicate(true)


## Walk the tree, and build an easy-to-read schema listing
#func schema():
  ## Build schema
  #var schema = new Data()
  #buildSchema(schema.cursor(''), cursor(''))
#
  ## Render it to a nice textual output
  #return renderSchema(schema.cursor(''))
#
#
## Takes a schema and dumps it out as text
#func renderSchema(cursor, indent):
  #if indent === undefined: indent = 0
  #var txt = ''
  #var keys = cursor.keys()
  #for (const key of keys) {
    ## Render current key as a line with indent
    #var outputKey = key == 'arrayMarker' ? '[...]' : key
    #var line = '  '.repeat(Math.max(0, indent - 1))
    #if indent > 0:
      #line += '  '
#
    #line += outputKey
    #txt += line + "\n"
#
    ## Recurse to children
    #var val = cursor.get_val(key)
    #if val instanceof DataCursor:
      #if val.keys()[0] == 'arrayMarker':
        ## Child is a numeric array
        #txt = txt.trim()
        #txt += renderSchema(cursor.cursor(key), indent)
      #else:
        #txt += renderSchema(cursor.cursor(key), indent + 1)
#
#
#
  #return txt
#
#
#func buildSchema(schemaCursor, srcCursor):
  #var schemaKey
  #var keys = srcCursor.keys()
  #for (const key of keys) {
    #if key.match(/\[.*\]/):
      #schemaKey = 'arrayMarker'
    #else:
      #schemaKey = key
#
    #var val = srcCursor.get_val(key)
    #if val instanceof DataCursor:
      ## Have to build sub stuff
      #if !schemaCursor.has_val(schemaKey):
        ## TODO: do we need to pass {} or [] here?
        #schemaCursor.set_val(schemaKey, {})
#
      #buildSchema(schemaCursor.cursor(schemaKey), srcCursor.cursor(key))
    #else:
      ## Just mark it as present
      #schemaCursor.set_val(schemaKey, true)
#
#
#
