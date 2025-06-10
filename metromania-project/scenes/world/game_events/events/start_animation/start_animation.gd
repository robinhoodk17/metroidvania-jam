extends GameEvent

@export var animationplayer : AnimationPlayer
@export var animation : String = ""
@export var delay : float = 0.0
@export var number_of_activations : int = 1
func activate():
	if number_of_activations == 0:
		return
	number_of_activations -= 1
	await get_tree().create_timer(delay).timeout
	if animation == "":
		if animationplayer.has_animation("new_animation"):
			animationplayer.play("new_animation")
			return
		else:
			push_warning(name, " has no animation name ")
	if animationplayer.has_animation(animation):
		animationplayer.play(animation)
	else:
		push_warning(name, " tried to call ", animation)
