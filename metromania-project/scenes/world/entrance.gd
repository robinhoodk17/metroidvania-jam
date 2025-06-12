extends Node3D
class_name entrance

@export var entrance_number : int = 0
@export var velocity : Vector3
func _ready() -> void:
	SignalbusPlayer.entered_level.connect(position_player)

func position_player(number : int) -> void:
	print_debug("emmited ",  number)
	if number == entrance_number:
		%Myck.global_position = global_position
		#%Myck.attach_camera()
		SignalbusPlayer.cam_attach.emit()
		%Myck.velocity = velocity
