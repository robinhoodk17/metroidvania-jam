class_name Progress extends Resource

@export var intro_player: bool
@export var boss_killed: bool
@export var player_has_done_thing: bool
@export var coins: int
@export var current_level: String
@export var check_point : Vector3

func _init() -> void:
	current_level = "room_1"
	coins = 1000
	check_point = Vector3.ZERO
