extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_nodes()
	hide()
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Escape"):
		get_tree().paused = !get_tree().paused
		if get_tree().paused:
			show()
		else:
			hide()
 
func _on_button_mouse_entered(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", Color(1.1, 1.1, 1.1, 1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_button_mouse_exited(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_start_pressed() -> void:
	print("Start Game pressed")
  
func _on_options_pressed() -> void:
	print("Options pressed")
   
func _on_quit_pressed() -> void:
	print("Quit pressed")
	get_tree().quit()

func create_nodes() -> void:
	var buttons = {
		"Resume": _on_start_pressed,
		"Options": _on_options_pressed,
		"Quit": _on_quit_pressed
	}
 
	for text in buttons.keys():
		var btn := Button.new()
		btn.text = text
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(200, 50)
		add_child(btn)
		btn.pressed.connect(buttons[text])
		btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
		btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
		btn.scale = Vector2.ONE
		btn.modulate = Color(1, 1, 1, 1)
		btn.custom_minimum_size = Vector2(200, 50)
		btn.offset_top = 10
		btn.offset_bottom = 10
