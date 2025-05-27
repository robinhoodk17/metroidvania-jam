extends Area3D

@export var hookshot_tip : Marker3D
@export var hookshot : Node3D
var target_position : Vector3
var flying : bool = false
var hooked : bool = false

func _ready() -> void:
	top_level = true
	#add exception player here

func _physics_process(_delta: float) -> void:
	global_position = hookshot_tip.global_position
	global_rotation = hookshot_tip.global_rotation
	if !flying:
		return
	if has_overlapping_bodies():
		hookshot.bumped(get_overlapping_bodies()[0], hookshot_tip.global_position)

	if global_position.distance_squared_to(target_position) < .01:
		hookshot.start_retracting()
