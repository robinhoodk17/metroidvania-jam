extends GameEvent

@export var delay : float = 1.0

func activate() -> void:
	await get_tree().create_timer(delay).timeout
	queue_free()
