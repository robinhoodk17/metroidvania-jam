extends Node

func _ready() -> void:
	SignalbusPlayer.entered_level.emit(Globals.player_entrance)
