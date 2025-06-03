extends GameEvent

@export var animationplayer : AnimationPlayer
@export var animation : String = ""

func activate():
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
