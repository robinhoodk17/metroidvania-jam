extends GameTrigger

var active_enemies : int = 0

func _ready() -> void:
	for i in get_overlapping_bodies():
		if i.is_in_group("enemy"):
			active_enemies += 1
	body_entered.connect(add_enemy)
	body_exited.connect(check_body)

func check_body(body : Node3D) -> void:
	if body.is_in_group("enemy"):
		active_enemies -= 1
		if active_enemies == 0:
			event_triggered.emit()

func add_enemy(body : Node3D) -> void:
	if body.is_in_group("enemy"):
		active_enemies += 1
