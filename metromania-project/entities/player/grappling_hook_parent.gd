extends Node3D

@export var hookshot_tip : Area3D
@export var hookspeed : float = 75.0
@export var player : PlayerController
var flying : bool = false
var hooked : bool = false
var target_position : Vector3
var retracting : bool = false
var hookshot_range : float = 10.0

func _physics_process(delta: float) -> void:
	if flying:
		look_at(target_position)
		scale.z += delta * hookspeed
		if scale.z > hookshot_range * 2.0:
			start_retracting()
	if retracting:
		scale.z -= delta * hookspeed
		if scale.z <= 1.0:
			end_retracting()
		

func start_hooking(_global_position, _target_position, _target_collider) -> void:
	scale.z = 1.0
	show()
	flying = true
	hooked = false
	target_position = _target_position
	hookshot_tip.target_position = _target_position
	hookshot_tip.flying = true
	hookshot_tip.hooked = false
	
func bumped(_collider : Node3D, _position : Vector3) -> void:
	flying = false
	hookshot_tip.flying = false
	hooked = true
	hookshot_tip.hooked = true
	player.current_action_state = PlayerController.action_state.FLYINGTOGRAPPLE
	player.hookshot_position = _position
	player.second_jump = false
	player.current_run_state = PlayerController.run_state.IDLE
	start_retracting()
	pass

func start_retracting() -> void:
	flying = false
	hookshot_tip.flying = false
	retracting = true
	pass

func end_retracting() -> void:
	hide()
	player.end_retracting()
	retracting = false
