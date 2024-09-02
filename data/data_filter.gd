# Represents a path component which acts as a filter on
# a node in the data graph.  e.g. data.get('foo[bar>5].some_key')
@tool
class_name DataFilter extends RefCounted

# Our state
var data
var path
var operator
var value

# Construct with a path array (as from tokenize()), an operator
# string, and a test value.
func _init(ndata, npath, noperator, nvalue):
  data = ndata
  path = npath
  operator = noperator
  value = nvalue

func _to_string():
  return "DataFilter<" + Data.join_path(path) + operator + str(value) + ">"

func is_valid():
  # Validate our path
  if not path is Array: return false
  for index in path:
    # Have to have explicit [] indices
    if index == null: return false
    # Only objects allowed in path are filters
    if typeof(index) == TYPE_OBJECT && not index is DataFilter: return false

  # Validate our operator
  if !Util.matches("/^(\\*|\\!?=|[><]=?)/", operator): return false

  return true

func test(node, key):
  # Star operator matches anything, no need for testing
  if operator == '*': return true

  # Otherwise, get the possible results
  var xpath = data.expand_path(path, node, key)
  var keys = xpath[0]
  var vals = xpath[1]

  # Filter out any cursors found - we just want leaf values
  vals = Util.filter(vals, func(v): not v is DataCursor)

  # And apply our operator + value test to 'em
  return test_values(vals)

func test_values(values):
    var op = operator
    var test_val = value

    if values.is_empty():
      # No value found, fail always
      return false

    elif values.size() == 1:
      # One value found, test singleton operators
      value = values[0]

      if op == "*":
        # Pass everything
        return true
      elif op == "=":
        # Equality
        return test_equality(test_val, value)
      elif (op == '!='):
        # Inequality
        return !test_equality(test_val, value)
      else:
        # Numeric ops, compare values
        var cmp = compare_numeric(value, test_val)
        # Invalid comparison - non-numeric val(s)
        if cmp == null: return false
        # Otherwise implement numeric tests
        match op:
          '>': return cmp == 1
          '>=': return cmp >= 0
          '<': return cmp == -1
          '<=': return cmp <= 0
          _: return false

    else:
      # Multiple values found, use set operators
      # ~= includes/any
      # *= all
      # #=/#>/#>= etc count
      return false

func test_equality(test, val):
    # Identicality means equality and works for strings
    if test == val: return true

    # Special cases for null and booleans to enable text matching
    if val == null: return test == "null"
    if val == true: return test == "true"
    if val == false: return test == "false"

    # Special case for numerics
    if Util.is_numeric(test) && Util.is_numeric(val):
      # Soft equals in PHP is pretty good here
      return test == val

    return false

func compare_numeric(test_val, val):
  if Util.is_numeric(test_val) && Util.is_numeric(val):
    if test_val > val: return 1
    if test_val < val: return -1
    return 0
  return null


