# A single state in a state machine.  Extend this class
# for each state you need in a given machine.
class_name State extends Node

# Ref to our owning state machine
@onready var state_machine: StateMachine = get_parent()

func on_enter():
	pass

func on_exit():
	pass

func handle_input(event):
	pass

func handle_process(delta):
	pass

func handle_physics_process(delta):
	pass
