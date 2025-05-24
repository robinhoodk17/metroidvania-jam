extends Node3D

signal player_space_pressed()
signal player_horizontal_input_changed(newInput: float)

func _ready():
	pass 

func _process(delta):
	player_horizontal_input_changed.emit(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		#toggle_pause()
		pass
	if get_tree().paused:
		return
	if event.is_action_pressed("Tab"):
		pass
	if event.is_action_pressed("Shift"):
		pass
	elif event.is_action_released("Shift"):
		pass
	if event.is_action_pressed("Space"):
		player_space_pressed.emit()
		pass
	if event.is_action_pressed("LMB"):
		pass
	if event.is_action_pressed("RMB"):
		pass
	elif event.is_action_released("RMB"):
		pass
	pass
