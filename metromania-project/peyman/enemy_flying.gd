extends CharacterBody3D

signal death(current_body : Node3D)

@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var animation_tree: AnimationTree = $AnimationTree

@export var maxhp : int = 1
@export var attack_cooldown: float = 3.0
@export var attack_speed: float = 15.0
@export var return_speed: float = 10.0
@export var hover_height: float = 5.0 + 5.0
@export var damage_amount: int = 10
@export var knockback_speed : float = 10.0
@export var knockback_resistance : float = 0.0

var hurt_box: Area3D  
var hit_box: Area3D
var upper_state: AnimationNodeStateMachinePlayback
var attack_timer: float = 0.0
var attacking: bool = false
var initial_position: Vector3
var _stunned_timer: Timer
var hurt : bool 
var stagger_position_target : Vector3
var hover_timer: Timer
var delay_retreat: bool
var hp : int = maxhp

func _ready():
	handle_first_adustments()
	create_hurt_box()
	create_stun_timer(0.1)
	create_hover_timer(1.0)
	initial_position = global_transform.origin
	upper_state  = animation_tree.get("parameters/StateMachine_upper/playback")
 
func handle_first_adustments() -> void:
	find_child("RobotArmature").scale = Vector3(0.5, 0.5, 0.5)
	add_to_group("enemy")
	axis_lock_linear_z = true

func create_stun_timer(time: float) -> void:
	_stunned_timer = Timer.new()
	add_child(_stunned_timer)              
	_stunned_timer.wait_time = time   
	_stunned_timer.one_shot = true   

func create_hover_timer(time: float) -> void:
	hover_timer = Timer.new()
	add_child(hover_timer)              
	hover_timer.wait_time = time   
	hover_timer.one_shot = true       

func _physics_process(delta) -> void:
	if hurt:
		velocity = stagger_position_target * knockback_speed
		move_and_slide()
		return
		
	attack_timer -= delta
	if not attacking:
		hover(delta)
		if attack_timer <= 0:
			attack()
	else:
		move_towards_player(delta)

func hover(delta) -> void:
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

func take_damage(amount : float, knockback : float = 0.0, _position : Vector3 = Vector3.ZERO) -> void:
	print_debug("enemy take damage")
	hp -= amount
	if hp <= 0:
		die()
		return
	hurt = true
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_stunned_timer.start()
	if knockback > knockback_resistance:
		stagger_position_target = global_position - _position
	await _stunned_timer.timeout
	hurt = false

func die() -> void:
	death.emit(self)
	queue_free()

func attack() -> void:
	attacking = true
	attack_timer = attack_cooldown

func move_towards_player(delta) -> void:
	var direction : Vector3 = (player.global_transform.origin - global_transform.origin).normalized()
	velocity = direction * attack_speed
	move_and_slide()
	if global_transform.origin.distance_to(player.global_transform.origin) < 2 && delay_retreat == false:
		deal_damage_to_player()
		if hurt == false:
			upper_state.travel("Robot_Punch")
			delay_retreat = true
			hover_timer.start()
			await hover_timer.timeout
			delay_retreat = false
			return_to_hover()
		else:
			return_to_hover()

func deal_damage_to_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(damage_amount)
	else:
		print("Player has no take_damage method!")

func return_to_hover() -> void:
	attacking = false
	await get_tree().create_timer(0.5).timeout
	initial_position = global_transform.origin

func create_hurt_box() -> void:
	hurt_box = Area3D.new()
	hurt_box.collision_layer = 1 << 5
	hurt_box.collision_mask = 0
	var collision_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.5 
	capsule_shape.height = 2.0  
	collision_shape.shape = capsule_shape
	hurt_box.add_child(collision_shape)
	hurt_box.monitoring = false
	hurt_box.position = Vector3(0, 1, 0)
	add_child(hurt_box)
 
