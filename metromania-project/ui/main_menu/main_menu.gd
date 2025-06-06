extends UiPage

# TODO: Add a title and/or background art to main_menu.tscn

func _ready() -> void:
	call_deferred("_connect_buttons")
	if OS.get_name() == "Web":
		%Exit.hide()


func _connect_buttons() -> void:
	if ui:
		%Play.pressed.connect(_start_game)
		%HowToPlay.pressed.connect(ui.go_to.bind("HowToPlay"))
		%Settings.pressed.connect(ui.go_to.bind("Settings"))
		%Controls.pressed.connect(ui.go_to.bind("Controls"))
		%Credits.pressed.connect(ui.go_to.bind("Credits"))
		%Exit.pressed.connect(get_tree().call_deferred.bind("quit"))

func show_ui() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func _start_game() -> void:
	# TODO: Consider adding some kind of scene transition
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Ui.go_to("Game")
	Utils.change_scene("uid://dqu1x7e4qyyv", 0)
	#get_tree().change_scene_to_file("uid://dqu1x7e4qyyv")
