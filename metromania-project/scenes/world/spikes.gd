extends Area3D

func _ready() -> void:
	area_entered.connect(check_area)


func check_area(area : Node3D) -> void:
	if area.has_method("take_damage_and_respawn"):
		area.take_damage_and_respawn(1)
