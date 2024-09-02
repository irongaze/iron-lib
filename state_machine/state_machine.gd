# Implements a state machine.  Derive from this class to build a state machine, with
# child State nodes controlling possible states
class_name StateMachine extends Node

# Fired when we transition to a new state
signal state_changed(newstate)

# Exports
@export var initial_state: State

# Our current state
var state

func _ready():
	# Init our kids' state
	for child in get_children():
		child.state_machine = self

	# Start up in our initial state
	state = initial_state
	state.on_enter()

func _unhandled_input(event):
	state.handle_input(event)

func _process(delta):
	state.handle_process(delta)

func _physics_process(delta):
	state.handle_physics_process(delta)

func transition_to(new_state):
	state.on_exit()
	state = get_node(new_state)
	state.on_enter()
	emit_signal('state_changed', new_state)
