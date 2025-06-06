extends GameEvent

@export var new_scene : String = ""
@export var entrance_number : int = 0

func activate():
	var player = %Myck
	Utils.change_scene(new_scene, player, entrance_number)
