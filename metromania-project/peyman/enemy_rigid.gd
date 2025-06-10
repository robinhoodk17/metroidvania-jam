extends RigidBody3D

signal death(current_body : Node3D)

@export var provoked: bool = true
@export var maxhp : int = 2
@export var patrol_points: Array[Vector3] = []
@export var chase_distance: float = 15.0 - 5.0
@export var attack_distance: float = 2.5 
@export var move_speed: float = 6.0
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 1.5
@export var knockback_resistance : float = 0.0
@export var knockback_speed : float = 10.0
var current_patrol_index: int = 0
var state: String = "patrol"  
var attack_timer: float = 0.0
var raycast: RayCast3D 
var hit_box:  Area3D
var bone_attachment : BoneAttachment3D
var locomotion: AnimationNodeStateMachinePlayback
var upper_state: AnimationNodeStateMachinePlayback
var distance_to_player : float
var hurt: bool

var hp = maxhp
var delay_rotation: bool 
var can_teleport: bool = true
var is_teleport: bool
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var pivot_node : Node3D = find_child("RobotArmature") 
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var hurt_box: Area3D = create_hurt_box()
@onready var nav_region: NavigationRegion3D = create_navmesh()
@onready var navigation_agent: NavigationAgent3D = create_navigation_agent()
@onready var _hitbox_timer: Timer =  create_timer(0.2)
@onready var _stunned_timer: Timer =  create_timer(0.08)
@onready var call_method_timer: Timer =  create_timer(0.26)
@onready var delay_timer: Timer =  create_timer(0.3)
@onready var slommo_timer: Timer =  create_timer(0.5)

func create_timer(wait_time: float = 1.0, one_shot: bool = true) -> Timer:
	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	add_child(timer)
	return timer

func _ready() -> void:  
	create_hitbox()
	create_partrol_points()
	add_to_group("enemy")
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	axis_lock_angular_y = true
	axis_lock_linear_z = true
	animation_tree.tree_root = animation_tree.tree_root.duplicate(true)
	navigation_agent.max_speed = move_speed
	upper_state  = animation_tree.get("parameters/StateMachine_upper/playback")
	locomotion = animation_tree.get("parameters/StateMachine_upper/locomotion/playback")
	pivot_node.get_child(0).scale = Vector3(0.5, 0.5, 0.5)
	set_patrol_target()

func _physics_process(delta) -> void:
	if linear_velocity.length() > 0.1:
		if locomotion.get_current_node() != "Robot_Walking":
			locomotion.travel("Robot_Running")
	else:
		if locomotion.get_current_node() != "Robot_Idle":
			locomotion.travel("Robot_Idle")
			
	if provoked == false:
		return
	distance_to_player = global_position.distance_to(player.global_position)
	rotate_pivot_toward_target(delta)
	
	match state:
		"patrol":
			if distance_to_player <= chase_distance:
				state = "chase"
				if can_teleport == false:
					can_teleport = true
			else:
				patrol_behavior(delta)
		"chase":
			if distance_to_player <= attack_distance:
				state = "attack"
				attack_timer = 0.0
			elif distance_to_player > chase_distance:
				state = "patrol"
				set_patrol_target()
				if can_teleport && is_teleport == false:
					teleport()
			else:
				chase_behavior(delta)
		"attack":
			if distance_to_player > attack_distance:
				state = "chase"
			else:
				attack_behavior(delta)

func chase_behavior(delta) -> void:
	var target_pos : Vector3 = player.global_position
	target_pos.y = global_position.y
	target_pos.z = global_position.z
	navigation_agent.set_target_position(target_pos)
	move_along_path(delta)
	
func attack_behavior(delta) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		perform_attack()
		attack_timer = attack_cooldown

func patrol_behavior(delta) -> void:
	if navigation_agent.is_navigation_finished():
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		set_patrol_target()
	move_along_path(delta)

func move_along_path(delta) -> void:
	if navigation_agent.is_navigation_finished():
		linear_velocity = Vector3.ZERO
		return
	var next_pos : Vector3 = navigation_agent.get_next_path_position()
	var direction : Vector3 = (next_pos - global_transform.origin)
	direction.y = 0
	direction.z = 0
	if direction.length() > 0:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO
	var desired_velocity : Vector3 = direction * move_speed
	var velocity_change : Vector3 = desired_velocity - linear_velocity
	var force : Vector3 = velocity_change * mass * 10.0
	apply_central_force(force)

func set_patrol_target() -> void:
	if patrol_points.size() == 0:
		return
	var target : Vector3 = patrol_points[current_patrol_index]
	target.y = global_transform.origin.y
	target.z = global_transform.origin.z
	navigation_agent.set_target_position(target)
 
#region create_nodes
func create_hurt_box() -> Area3D:
	hurt_box = Area3D.new()
	hurt_box.collision_layer = 1 << 5
	hurt_box.collision_mask = 0
	var collision_shape : CollisionShape3D = CollisionShape3D.new()
	var capsule_shape : CapsuleShape3D = CapsuleShape3D.new()
	capsule_shape.radius = 0.5 
	capsule_shape.height = 2.0  
	collision_shape.shape = capsule_shape
	hurt_box.add_child(collision_shape)
	hurt_box.monitoring = false
	hurt_box.position = Vector3(0, 1, 0)
	add_child(hurt_box)
	return hurt_box
 
func create_hitbox() -> void:
	var skeleton : Skeleton3D = find_child("Skeleton3D")  
	if not skeleton:
		push_error("Enemy Skeleton3D node not found!")
		return
	bone_attachment = BoneAttachment3D.new()
	skeleton.add_child(bone_attachment)
	hit_box = Area3D.new()
	hit_box.name = "hit_box"
	hit_box.collision_layer = 0
	hit_box.collision_mask = 1 << 4
	var collision_shape_hit : CollisionShape3D = CollisionShape3D.new()
	var sphere_shape : SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.5 * 2
	hit_box.monitorable = false
	hit_box.monitoring = false
	collision_shape_hit.shape = sphere_shape
	hit_box.add_child(collision_shape_hit)
	bone_attachment.add_child(hit_box)
	bone_attachment.bone_name = "Palm1.R"
	hit_box.area_entered.connect(func(area: Area3D): if area.owner.has_method("take_damage") && area.owner.is_in_group("player"):
		area.owner.take_damage(10))

func create_navmesh() -> NavigationRegion3D:
	nav_region = NavigationRegion3D.new()
	var nav_mesh : NavigationMesh = NavigationMesh.new()
	var half_size : float = 2.0
	var vertices : PackedVector3Array = PackedVector3Array([
		Vector3(-half_size, 0, -half_size),
		Vector3(half_size, 0, -half_size),
		Vector3(half_size, 0, half_size),
		Vector3(-half_size, 0, half_size),
	])
	var polygons : PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
	nav_mesh.vertices = vertices
	nav_mesh.add_polygon(polygons)
	nav_region.navmesh = nav_mesh
	add_child(nav_region)
	return nav_region

func create_navigation_agent() -> NavigationAgent3D:
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	return navigation_agent
 
func create_partrol_points() -> void:
	var patrol_distance : float = 2.0
	var left_dir : Vector3 = -global_transform.basis.x.normalized()
	var right_dir : Vector3 = global_transform.basis.x.normalized()
	var left_point : Vector3 = global_position + left_dir * patrol_distance
	var right_point : Vector3 = global_position + right_dir * patrol_distance
	patrol_points.append(left_point)
	patrol_points.append(right_point)
 
func enable_hit_box() -> void:
	hit_box.monitoring = true
	_hitbox_timer.start()
	await _hitbox_timer.timeout
	hit_box.monitoring = false
 
#endregion
 
func perform_attack() -> void:
	upper_state.travel("Robot_Punch")
	call_method_timer.start()
	await call_method_timer.timeout
	enable_hit_box()

func take_damage(amount : float, knockback : float = 0.0, _position : Vector3 = Vector3.ZERO) -> void:
	hp -= amount
	if hp <= 0:
		die()
		return
	hurt = true
	var nav_rid : RID = nav_region.get_rid()
	var stagger_position_target : Vector3
	NavigationServer3D.region_set_enabled(nav_rid, false)
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_stunned_timer.start()
	if knockback > knockback_resistance:
		stagger_position_target = global_position - _position
	linear_velocity = (stagger_position_target * knockback_speed) 
	await _stunned_timer.timeout
	hurt = false
	delay_rotation = true
	NavigationServer3D.region_set_enabled(nav_rid, true)
	delay_timer.start()
	await delay_timer.timeout
	delay_rotation = false
   

func die() -> void:
	death.emit(self)
	SignalbusPlayer.cam_shake.emit()
	SignalbusPlayer.cam_tilt.emit()
	SignalbusPlayer.cam_zoom_in_out.emit()
	enemy_slowmo(0.7)
	await get_tree().create_timer(1).timeout
	queue_free()

func enemy_slowmo(slowmotion_factor : float = 0.5) -> void:
	slommo_timer.start()
	slowmotion_factor = clamp(0.5, 0.0, 1.0)
	animation_tree.set("parameters/TimeScale/scale", slowmotion_factor)
	await slommo_timer.timeout
	animation_tree.set("parameters/TimeScale/scale", 1.0)

func rotate_pivot_toward_target(delta) -> void:
	if delay_rotation or hurt:
		return
	if distance_to_player > attack_distance:
		var vel : Vector3 = linear_velocity
		if vel.length() < 0.1:
			return
		vel.y = 0
		if vel.length() == 0:
			return
		vel = vel.normalized()
		var target_angle : float = atan2(vel.x, vel.z)
		var new_basis : Basis = Basis(Vector3.UP, target_angle)
		var new_transform : Transform3D = pivot_node.global_transform
		new_transform.basis = new_basis
		pivot_node.global_transform = new_transform
	else:
		var direction : Vector3 = player.position - pivot_node.global_position
		direction.y = 0
		if direction.length() == 0:
			return  
		direction = direction.normalized()
		var current_yaw : float = pivot_node.rotation.y
		var target_yaw : float = atan2(direction.x, direction.z)
		var new_yaw : float = lerp_angle(current_yaw, target_yaw, rotation_speed * delta)
		pivot_node.rotation = Vector3(0, new_yaw, 0)

func teleport() -> void:
	delay_timer.start()
	var player_forward : Vector3 = -player.global_transform.basis.x.normalized()
	global_position = player.global_position + player_forward * 3.0
	pivot_node.look_at(player.global_position, Vector3.UP)
	is_teleport = true
	await get_tree().create_timer(3).timeout
	is_teleport = false
