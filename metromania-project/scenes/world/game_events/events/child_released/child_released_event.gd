extends GameEvent

func activate():
	SignalbusPlayer.child_released.emit()
