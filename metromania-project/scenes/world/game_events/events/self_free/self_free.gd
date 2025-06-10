extends GameEvent

@export var delay : float = 1.0
@export var free_others : Array[Node3D]

func activate() -> void:
	await get_tree().create_timer(delay).timeout
	for others in free_others:
		others.queue_free()
	queue_free()
