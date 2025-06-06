extends GameEvent

@export var animationplayer : AnimationPlayer
@export var delay : float = 0.0

func activate():
	await get_tree().create_timer(delay).timeout
	animationplayer.pause()
