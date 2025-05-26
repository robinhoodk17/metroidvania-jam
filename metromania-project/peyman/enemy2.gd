extends CharacterBody3D
class_name Enemy
 
@export var detection_radius: float = 15.0
@export var attack_range: float = 2.5
@export var speed_walk: float = 3.0 + 1.0
@export var speed_run: float = 6.0 + 3.0
@export var attack_cooldown: float = 1.5
@export var hit_recovery_time: float = 0.7
@export var max_health := 100
@export var attack_distance: float = 2.5
@onready var animation_tree: AnimationTree = $AnimationTree 
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var health := max_health
 
enum State { IDLE, PATROL, CHASE, ATTACK, HIT }
const TELEPORT_DISTANCE := 20.0
const TELEPORT_OFFSET := 3.0
var current_state = State.IDLE
var patrol_points: Array[Vector3] = []
var patrol_distance := 2.0
var obstacle_detection_distance := 3.0
var stuck_distance_threshold := 0.1 
var current_patrol_index = 0
var attack_timer = 0.0
var hit_timer = 0.0
var distance : float 
var label_3d: Label3D 
var raycast: RayCast3D 
var hurt_box: Area3D 
var navigation_agent: NavigationAgent3D  
var upper_animation : AnimationNodeStateMachinePlayback
var locomotion : AnimationNodeStateMachinePlayback
var oneshot_animation : AnimationNode
var provoked: bool
var can_move := true
var jump_velocity := 13.0
var is_jumping: bool
const ENEMY_TREE = preload("res://peyman/enemy_tree.tres")

func _ready():
	set_physics_process(false)
	handle_the_nodes()
	animation_tree.tree_root = ENEMY_TREE
	upper_animation = animation_tree.get("parameters/StateMachine_upper/playback")
	oneshot_animation = animation_tree.get_tree_root().get_node("OneShotAnimation")
	locomotion = animation_tree.get("parameters/StateMachine_upper/locomotion/playback")
	navigation_agent.max_speed = speed_walk
	handle_adustments()
	call_deferred("set_physics_process", true)
 
func handle_the_rest(delta: float) -> void:
	###handle_gravity
	if !is_on_floor():
		if velocity.y < 0:
			velocity += get_gravity() * 10 * delta
		else:
			velocity += get_gravity() * 10 * delta
	if velocity.x > 0:
		$MeshParent.basis = Basis.FLIP_X
	if  velocity.x < 0:
		$MeshParent.basis = Basis.IDENTITY
 
	###handle_animations 
	if velocity.length() > 0.1:
		if locomotion.get_current_node() != "Robot_Walking":
			locomotion.travel("Robot_Running")
	else:
		if locomotion.get_current_node() != "Robot_Idle":
			locomotion.travel("Robot_Idle")
 
	###handle_teleport
	distance = global_position.distance_to(player.global_position)
	if distance > TELEPORT_DISTANCE && provoked:
		if health < (max_health/3.0):
			teleport()
		else:
			provoked = false
			set_state(State.IDLE)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			handle_idle(delta)
		State.PATROL:
			handle_patrol(delta)
		State.CHASE:
			handle_chase(delta)
		State.ATTACK:
			handle_attack(delta)
		State.HIT:
			handle_hit(delta)
	handle_the_rest(delta)
	move_and_slide()

func set_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		State.IDLE:
			velocity = Vector3.ZERO
			navigation_agent.set_target_position(global_transform.origin)
		State.PATROL:
			if patrol_points.size() > 0:
				navigation_agent.set_target_position(patrol_points[current_patrol_index])
				navigation_agent.max_speed = speed_walk
		State.CHASE:
			navigation_agent.max_speed = speed_run
		State.ATTACK:
			velocity = Vector3.ZERO
		State.HIT:
			velocity = Vector3.ZERO
			hit_timer = 0.0

func can_see_player() -> bool:
	var to_player := player.global_position - global_position
	if to_player.length() > detection_radius:
		return false
	if raycast.is_colliding():
		if raycast.get_collider() == player:
			provoked = true 
	return provoked

func handle_idle(delta):
	if can_see_player():
		set_state(State.CHASE)
	else:
		set_state(State.PATROL)

func handle_patrol(delta):
	if can_see_player():
		set_state(State.CHASE)
		return

	if navigation_agent.is_navigation_finished():
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		navigation_agent.set_target_position(patrol_points[current_patrol_index])
	move_along_path(delta)

func handle_chase(delta):
	if not can_see_player():
		set_state(State.PATROL)
		return
	if raycast.is_colliding() && raycast.get_collider() != player:
		perform_jump()
	if distance <= attack_range:
		set_state(State.ATTACK)
		return

	navigation_agent.set_target_position(player.global_position)
	move_along_path(delta)

func handle_attack(delta):
	if not distance <= attack_range && can_move:
		set_state(State.CHASE)
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		perform_attack()
		attack_timer = attack_cooldown

func handle_hit(delta):
	hit_timer += delta
	if hit_timer >= hit_recovery_time:
		if can_see_player():
			set_state(State.CHASE)
		else:
			set_state(State.PATROL)

func move_along_path(delta):
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		###move_and_slide()
		return
	var direction = (navigation_agent.get_next_path_position() - global_position)
	direction.y = 0  
	if direction.length() < 0.1:
		velocity = Vector3.ZERO
		###move_and_slide()
		return
	direction = direction.normalized()
	var local_x = global_transform.basis.x.normalized() 
	var move_vector = local_x * direction.dot(local_x) * speed_walk
	velocity.x = move_vector.x
	velocity.z = move_vector.z
	###move_and_slide()

func take_damage(amount):
	set_state(State.HIT)
	health = max(max_health - amount, 0)
	if health == 0: 
		collision_layer = 0
		collision_mask = 1
		hurt_box.set_deferred("monitorable", false)
	else:
		pass
		###play hit animation
 
func perform_attack():
	var chosen_attack := randi() % 3 
	#var chosen_attack := get_player_action()
	can_move = false 
	$OffTimer.start()
	
	match chosen_attack:
		0:
			label_3d.text = "BASIC_ATTACK"
			Music.play_sfx($AudioStreamPlayer3D, "cat")
		1:
			label_3d.text = "jump_ATTACK"
			Music.play_sfx($AudioStreamPlayer3D, "EnemyCry")
		#2:
			#label_3d.text = "BASIC_ATTACK"

func perform_jump() -> void:
	if is_jumping == false:
		is_jumping = true
		velocity.y = jump_velocity * 2
		await get_tree().create_timer(1).timeout
		is_jumping = false
 
func _on_off_timer_timeout() -> void:
	can_move = true

#region nodes
func handle_the_nodes() -> void:
	###create_off_timer
	var off_timer = Timer.new()
	off_timer.name = "OffTimer"
	off_timer.one_shot = true
	off_timer.wait_time = 1.5  
	off_timer.autostart = false
	add_child(off_timer)
	off_timer.timeout.connect(_on_off_timer_timeout)
	
	###create_navigation_agent
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	
	###create_player_detect_raycast
	raycast = RayCast3D.new()
	raycast.enabled = true 
	raycast.target_position = Vector3(3, 0, 0)  
	raycast.exclude_parent = true  
	$MeshParent.add_child(raycast)
	raycast.collision_mask = (1 << 0) | (1 << 2)
	
	###create_hurt_box
	hurt_box = Area3D.new()
	hurt_box.collision_layer = 1 << 5
	var collision_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.5
	capsule_shape.height = 2.0
	collision_shape.shape = capsule_shape
	hurt_box.add_child(collision_shape)
	hurt_box.monitoring = false
	hurt_box.collision_mask = 0
	add_child(hurt_box)
	
	###create_label_3d
	label_3d = Label3D.new()
	add_child(label_3d)
	label_3d.global_position = global_position + Vector3(0, 1.5, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	###create_navmesh
	var nav_region = NavigationRegion3D.new()
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
#endregion 
func handle_adustments() -> void:
	set_state(State.IDLE)
	###initial_adustments
	rotate_y(deg_to_rad(180))
	collision_layer = 1 << 1
	collision_mask = (1 << 0) | (1 << 2)
	axis_lock_linear_z = true
	
	###create_partrol_points_around_character
	var left_dir = -global_transform.basis.x.normalized()
	var right_dir = global_transform.basis.x.normalized()
	var left_point = global_position + left_dir * patrol_distance
	var right_point = global_position + right_dir * patrol_distance
	patrol_points.append(left_point)
	patrol_points.append(right_point)

#func get_player_action() -> int:
	#pass 
	#if player.is_attacking:
		#return 1
	##elif player.is_jumping:
		##1
	#else: 
		#return 0
	#return 2

func teleport() -> void:
	var player_forward = -player.global_transform.basis.x.normalized()
	global_position = player.global_position + player_forward * TELEPORT_OFFSET
	$MeshParent.look_at(player.global_position, Vector3.UP)
 
