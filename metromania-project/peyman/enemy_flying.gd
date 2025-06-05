extends CharacterBody3D

@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var animation_tree: AnimationTree = $AnimationTree

@export var attack_cooldown: float = 3.0
@export var attack_speed: float = 15.0
@export var return_speed: float = 10.0
@export var hover_height: float = 5.0 + 5.0
@export var damage_amount: int = 10
 
var upper_state: AnimationNodeStateMachinePlayback
var attack_timer: float = 0.0
var attacking: bool = false
var initial_position: Vector3

func _ready():
	handle_first_adustments()
	initial_position = global_transform.origin

func _physics_process(delta):
	attack_timer -= delta
	if not attacking:
		hover(delta)
		if attack_timer <= 0:
			attack()
	else:
		move_towards_player(delta)

func hover(delta):
	var target_position : Vector3 = initial_position + Vector3(0, hover_height, 0)
	var direction : Vector3 = (target_position - global_transform.origin).normalized()
	velocity = direction * return_speed
	move_and_slide()
	var player_position_xz : Vector3 = Vector3(player.global_transform.origin.x, global_transform.origin.y, player.global_transform.origin.z)
	var distance_to_player : float = player_position_xz.distance_to(global_transform.origin)
	if distance_to_player > 10:
		var return_direction = (player_position_xz - global_transform.origin).normalized()
		velocity = return_direction * return_speed
		move_and_slide()

func attack():
	attacking = true
	attack_timer = attack_cooldown

func move_towards_player(delta):
	var direction : Vector3 = (player.global_transform.origin - global_transform.origin).normalized()
	velocity = direction * attack_speed
	move_and_slide()
	if global_transform.origin.distance_to(player.global_transform.origin) < 2:
		deal_damage_to_player()
		return_to_hover()

func deal_damage_to_player():
	if player.has_method("take_damage"):
		player.take_damage(damage_amount)
	else:
		print("Player has no take_damage method!")

func return_to_hover():
	attacking = false
	await get_tree().create_timer(0.5).timeout
	initial_position = global_transform.origin

func handle_first_adustments() -> void:
	find_child("RobotArmature").scale = Vector3(0.5, 0.5, 0.5)
	add_to_group("enemy")
	axis_lock_linear_z = true
