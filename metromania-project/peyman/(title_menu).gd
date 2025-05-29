extends Control

func _ready():
	name = "Main_Menu"
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
 
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -120
	vbox.offset_top = -90
	vbox.offset_right = 120
	vbox.offset_bottom = 90
	vbox.GROW_DIRECTION_BEGIN
  
	var buttons = {
		"Start Game": _on_start_pressed,
		"Options": _on_options_pressed,
		"Quit": _on_quit_pressed
	}
 
	for text in buttons.keys():
		var btn := Button.new()
		btn.text = text
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(200, 50)
		vbox.add_child(btn)
		btn.pressed.connect(buttons[text])
		btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
		btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
		btn.scale = Vector2.ONE
		btn.modulate = Color(1, 1, 1, 1)

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
