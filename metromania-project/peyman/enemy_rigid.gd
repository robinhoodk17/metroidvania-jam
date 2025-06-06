extends RigidBody3D
@export var provoked: bool = true
@export var patrol_points: Array[Vector3] = []
@export var chase_distance: float = 15.0 - 5.0
@export var attack_distance: float = 2.5 
@export var move_speed: float = 6.0
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 1.5
@export var knockback_resistance : float = 0.0
@export var knockback_speed : float = 10.0
@onready var animation_tree: AnimationTree = $AnimationTree
var current_patrol_index: int = 0
var state: String = "patrol"  
var attack_timer: float = 0.0
@onready var pivot_node : Node3D = find_child("RobotArmature") 
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
var navigation_agent: NavigationAgent3D
var nav_region: NavigationRegion3D
var raycast: RayCast3D 
var hurt_box: Area3D 
var hit_box:  Area3D
var bone_attachment : BoneAttachment3D
var locomotion: AnimationNodeStateMachinePlayback
var upper_state: AnimationNodeStateMachinePlayback
var distance_to_player : float
var hurt: bool
var _hitbox_timer: Timer
var _stunned_timer: Timer
var call_method_timer: Timer
var delay_timer: Timer
var delay_rotation: bool 

func _ready() -> void:
	create_navmesh()
	create_navigation_agent()   
	create_partrol_points()
	create_hitbox()
	create_hurt_box()
	create_hitbox_timer(0.2)
	create_stun_timer(0.08)
	create_call_method_timer(0.26)
	create_delay_rotatoin_timer(0.3)
	navigation_agent.max_speed = move_speed
	upper_state  = animation_tree.get("parameters/StateMachine_upper/playback")
	locomotion = animation_tree.get("parameters/StateMachine_upper/locomotion/playback")
	set_patrol_target()
	handle_first_adustments()

func handle_first_adustments() -> void:
	pivot_node.get_child(0).scale = Vector3(0.5, 0.5, 0.5)
	add_to_group("enemy")
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	axis_lock_angular_y = true
	axis_lock_linear_z = true

func _physics_process(delta) -> void:
	if linear_velocity.length() > 0.1:
		if locomotion.get_current_node() != "Robot_Walking":
			locomotion.travel("Robot_Running")
	else:
		if locomotion.get_current_node() != "Robot_Idle":
			locomotion.travel("Robot_Idle")
			
	distance_to_player = global_position.distance_to(player.global_position)
	rotate_pivot_toward_target(delta)
	
	match state:
		"patrol":
			if distance_to_player <= chase_distance:
				state = "chase"
			else:
				patrol_behavior(delta)
		"chase":
			if distance_to_player <= attack_distance:
				state = "attack"
				attack_timer = 0.0
			elif distance_to_player > chase_distance:
				state = "patrol"
				set_patrol_target()
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
	if attack_timer <= 0.0 && provoked:
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
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_transform.origin)
	direction.y = 0
	direction.z = 0
	if direction.length() > 0:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO
	var desired_velocity = direction * move_speed
	var velocity_change = desired_velocity - linear_velocity
	var force = velocity_change * mass * 10.0
	apply_central_force(force)

func set_patrol_target() -> void:
	if patrol_points.size() == 0:
		return
	var target = patrol_points[current_patrol_index]
	target.y = global_transform.origin.y
	target.z = global_transform.origin.z
	navigation_agent.set_target_position(target)
 
#region create_nodes
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
 
func create_hitbox() -> void:
	var skeleton = find_child("Skeleton3D")  
	if not skeleton:
		push_error("Enemy Skeleton3D node not found!")
		return
	bone_attachment = BoneAttachment3D.new()
	skeleton.add_child(bone_attachment)
	hit_box = Area3D.new()
	hit_box.name = "hit_box"
	hit_box.collision_layer = 0
	hit_box.collision_mask = 1 << 4
	var collision_shape_hit := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.5 * 2
	hit_box.monitorable = false
	hit_box.monitoring = false
	collision_shape_hit.shape = sphere_shape
	hit_box.add_child(collision_shape_hit)
	bone_attachment.add_child(hit_box)
	bone_attachment.bone_name = "Palm1.R"
	hit_box.area_entered.connect(func(area: Area3D): if area.owner.has_method("take_damage") && area.owner.is_in_group("player"):
		area.owner.take_damage(10))

func create_navmesh() -> void:
	nav_region = NavigationRegion3D.new()
	var nav_mesh = NavigationMesh.new()
	var half_size = 2.0
	var vertices = PackedVector3Array([
		Vector3(-half_size, 0, -half_size),
		Vector3(half_size, 0, -half_size),
		Vector3(half_size, 0, half_size),
		Vector3(-half_size, 0, half_size),
	])
	var polygons = PackedInt32Array([0, 1, 2, 3])
	nav_mesh.vertices = vertices
	nav_mesh.add_polygon(polygons)
	nav_region.navmesh = nav_mesh
	add_child(nav_region)

func create_navigation_agent() -> void:
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
 
func create_partrol_points() -> void:
	var patrol_distance : float = 2.0
	var left_dir = -global_transform.basis.x.normalized()
	var right_dir = global_transform.basis.x.normalized()
	var left_point = global_position + left_dir * patrol_distance
	var right_point = global_position + right_dir * patrol_distance
	patrol_points.append(left_point)
	patrol_points.append(right_point)
 
func enable_hit_box() -> void:
	hit_box.monitoring = true
	_hitbox_timer.start()
	await _hitbox_timer.timeout
	hit_box.monitoring = false
	
func create_hitbox_timer(time: float) -> void:
	_hitbox_timer = Timer.new()
	add_child(_hitbox_timer)              
	_hitbox_timer.wait_time = time    
	_hitbox_timer.one_shot = true     
	
func create_stun_timer(time: float) -> void:
	_stunned_timer = Timer.new()
	add_child(_stunned_timer)              
	_stunned_timer.wait_time = time   
	_stunned_timer.one_shot = true         
 
func create_call_method_timer(time: float) -> void:
	call_method_timer = Timer.new()
	add_child(call_method_timer)              
	call_method_timer.wait_time = time   
	call_method_timer.one_shot = true
	
func create_delay_rotatoin_timer(time: float) -> void:
	delay_timer = Timer.new()
	add_child(delay_timer)              
	delay_timer.wait_time = time   
	delay_timer.one_shot = true
 
#endregion
 
func perform_attack() -> void:
	upper_state.travel("Robot_Punch")
	call_method_timer.start()
	await call_method_timer.timeout
	enable_hit_box()
  
func take_damage(amount : float, knockback : float = 0.0, _position : Vector3 = Vector3.ZERO) -> void:
	print_debug("enemy take damage")
	hurt = true
	var nav_rid = nav_region.get_rid()
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
		var target_angle = atan2(vel.x, vel.z)
		var new_basis = Basis(Vector3.UP, target_angle)
		var new_transform = pivot_node.global_transform
		new_transform.basis = new_basis
		pivot_node.global_transform = new_transform
	else:
		var direction = player.position - pivot_node.global_position
		direction.y = 0
		if direction.length() == 0:
			return  
		direction = direction.normalized()
		var current_yaw = pivot_node.rotation.y
		var target_yaw = atan2(direction.x, direction.z)
		var new_yaw = lerp_angle(current_yaw, target_yaw, rotation_speed * delta)
		pivot_node.rotation = Vector3(0, new_yaw, 0)
 
