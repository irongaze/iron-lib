extends Node

# Max HP
@export var max_hp: int = 100

# Current HP
@onready var current_hp: int = max_hp

func take_damage(damage):
	pass
