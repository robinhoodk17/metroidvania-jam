extends GameEvent

func activate():
	SignalbusPlayer.child_captured.emit()
