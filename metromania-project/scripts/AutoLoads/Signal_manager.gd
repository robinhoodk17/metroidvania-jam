extends Node

signal	spawn_enemies(Node3D, Vector3)
# Called when the node enters the scene tree for the first time.
func _ready():
	spawn_enemies.connect(handle_spawn_enemies)
	pass # Replace with function body.

func handle_spawn_enemies(what : Node3D, where : Vector3):
	get_tree().root.add_child(what)
	what.global_position = where
