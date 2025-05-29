extends AnimationPlayer

func _ready() -> void:
	callback_mode_process  = AnimationCallbackModeProcess.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS 
	play("new_animation")
