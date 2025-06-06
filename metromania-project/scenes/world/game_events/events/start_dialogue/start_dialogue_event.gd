extends GameEvent

@export var timeline : String = "whoops"

func activate():
	Utils.start_dialogue(timeline)
