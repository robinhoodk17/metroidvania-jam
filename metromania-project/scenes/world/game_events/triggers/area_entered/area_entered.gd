extends GameTrigger

func _ready() -> void:
	body_entered.connect(check_for_player)

func check_for_player(body : Node3D) -> void:
	if body.is_in_group("player"):
		event_triggered.emit()
