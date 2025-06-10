extends Label

func _process(delta: float) -> void:
	Engine.get_process_frames()
	text = str("FPS: ", Engine.get_frames_per_second())
