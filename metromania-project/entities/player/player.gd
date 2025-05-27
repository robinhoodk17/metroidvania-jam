extends CharacterBody3D
class_name PlayerController

enum run_state {IDLE, WALKING, RUNNING, BRAKING, WALL_SLIDING, STAGGERING, LEDGE_GRABBING}
enum action_state{IDLE_ACTION, ATTACKING, LANDING, GRAPPLING, FLYINGTOGRAPPLE, STAGGERING, HOOKED, JUMPING, BLOCKED}
enum inputs{JUMP, ATTACK, THROW_CHILD, DASH, NONE}

@export var slow_time : bool = false
@export_group("Player Movement")
##how long an action remains queued before it gets deleted
##for example, when a player jumps before reaching the ground
@export var queue_time : float = 0.35
@export_subgroup("running")
##player max speed
@export var speed : float = 0.5
##how accelerating from 0 to max speed looks like
@export var acceleration_curve : Curve
@export var deceleration_curve : Curve
##the number of seconds required to accelerate from 0 to max speed
@export var acceleration : float = 0.7
##the number of seconds required to brake from max to 0
@export var deceleration : float = .15
@export_subgroup("jump")
@export var jump_velocity : float = 15.0
@export var jump_floatiness : float = 0.15
##how big is gravity
@export var going_down_speed : float = 3.0
@export_subgroup("wall jump")
##the velocity in x repulsing the player from the wall
@export var wall_jump_repulsion : float = 10.0
@export var wall_jump_time : float = 0.25
##when the player is pressing against a wall, how much it stops falling
@export var wall_slide_gravity : float = 0.2
@export var dash_velocity : float = 30.0
@export var dash_duration : float = 0.5
@export var coyote_time : float = 0.1
@export var ledge_grab_offset : float = -.5
@export_group("Combat")
@export var combo_reset : float = 1.5
@export var max_combo : int = 3
@export_group("Hookshot")
@export var hookshot_range : float = 10.0
@export var movement_to_grapple_speed : float = 40.0
@export var gravity_damp_while_hooking : float = 0.25
@export_group("Camera")
@export var dampen_frames : int = 20
@export_group("Nodes")
@export var mesh : Marker3D

@onready var camera_pivot: Node3D = $CameraPivot
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var combo_reset_timer: Timer = $ComboResetTimer
@onready var dash_reset_timer: Timer = $DashResetTimer
@onready var queue_timer: Timer = $QueueTimer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var grappling_hook : Node3D = $GrapplingHookParent
@onready var wall_jump: ShapeCast3D = $MeshParent/WallJump
@onready var ledge_grab: RayCast3D = $MeshParent/LedgeGrab
@onready var check_collisions: RayCast3D = $MeshParent/LedgeGrab/CheckCollisions

"""child interaction"""
@onready var alice: CharacterBody3D = $MeshParent/ChildContainer/Alice
@onready var pick_child: Area3D = $MeshParent/PickChild
@onready var auto_aim: Area3D = $MeshParent/AutoAim

"""state machine"""
var current_run_state : run_state = run_state.IDLE
var current_action_state : action_state = action_state.IDLE_ACTION

var carrying_child : bool = true
var direction_x : float = 0.0
var running_time : float = 0.0
var braking_time : float = 0.0
var jumping_time : float = 0.0
var second_jump : bool = false
var dash_spent : bool = false
var combo_number : int = 0
var input_queued : inputs = inputs.NONE
var hookshot_position : Vector3
var animating : bool = false
var current_gravity_force : float = 1.0

"""camera"""
var dampened_y_array : Array[float]
var averaged_y : float
var current_y : int = 0
var screen_middle : Vector2

"""animation"""
var run_animation : AnimationNodeStateMachinePlayback
var action_animation : AnimationNodeStateMachinePlayback
var oneshot_animation : AnimationNode



func _ready() -> void:
	SignalbusPlayer.child_picked_up.connect(pick_up_child)
	SignalbusPlayer.start_grapple.connect(start_grapple)
	SignalbusPlayer.end_retracting.connect(end_retracting)
	pick_child.connect("body_entered",pick_up_child)
	screen_middle = DisplayServer.screen_get_size()/2
	dash_reset_timer.timeout.connect(change_action_state)
	"""setting up animations"""
	run_animation = animation_tree.get("parameters/StateMachine_running/playback")
	action_animation = animation_tree.get("parameters/StateMachine_action/playback")
	oneshot_animation = animation_tree.get_tree_root().get_node("OneShotAnimation")
	for i : int in range(dampen_frames):
		dampened_y_array.append(global_position.y)
		averaged_y = global_position.y

func pick_up_child(_body : Node3D = null):
	if carrying_child:
		return
	if _body == null:
		carrying_child = true
		return
		
	if _body.is_in_group("player"):
		_body.turn_off()
		carrying_child = true

func _physics_process(delta: float) -> void:
	if slow_time:
		Engine.time_scale = 0.25
	position_camera(delta)
	run_state_machine(delta)
	action_state_machine(delta)
	handle_gravity(delta)

	move_and_slide()

func position_camera(delta: float) -> void:
	current_y = (current_y + 1) % dampened_y_array.size()
	dampened_y_array[current_y] = global_position.y
	var running_sum : float = 0.0
	for i : float in dampened_y_array:
		running_sum += i
	averaged_y = running_sum/dampened_y_array.size()
	if is_on_floor():
		camera_pivot.global_position = lerp(camera_pivot.global_position, global_position, 5.0 * delta)
	else:
		var target_position = Vector3(global_position.x, averaged_y, global_position.z)
		camera_pivot.global_position = lerp(camera_pivot.global_position, target_position, 2.5 * delta)

func run_state_machine(delta: float) -> void:
	if current_action_state == action_state.FLYINGTOGRAPPLE:
		velocity = (hookshot_position - global_position).normalized() * movement_to_grapple_speed
		run_animation.travel("idle")
		return
		
	if current_action_state == action_state.HOOKED:
		velocity = Vector3.ZERO
		run_animation.travel("idle")
		return
		
	var run_direction = Input.get_axis("move_left", "move_right")
	
	if ledge_grab.is_colliding() and !check_collisions.is_colliding():
		if velocity.y < 0:
			if !is_on_floor():
				var collision_point : Vector3 = ledge_grab.get_collision_point()
				if (collision_point - global_position).x * run_direction > 0:
					current_action_state = action_state.IDLE_ACTION
					current_run_state = run_state.LEDGE_GRABBING
					velocity = Vector3.ZERO
					global_position.y = collision_point.y + ledge_grab_offset
					second_jump = false
					dash_spent = false
					return
	
	if wall_jump.is_colliding() and !current_run_state == run_state.LEDGE_GRABBING:
		#print_debug("overlapping bodies and not ledge grab ", current_action_state)
		if run_direction * mesh.global_basis.z.z > 0 and !is_on_floor():
			#print_debug("facing and pressing button")
			if current_run_state != run_state.WALL_SLIDING:
				if velocity.y < 0:
					velocity.y = 0
			current_run_state = run_state.WALL_SLIDING
			#print_debug("wall sliding")
	
	if current_action_state == action_state.BLOCKED:
		return
	
	match current_run_state:
		run_state.IDLE:
			if is_on_floor():
				running_time = move_toward(running_time, 0.0, delta * 2.0)
			if !animating:
				run_animation.travel("idle")
			if run_direction != 0.0:
				if abs(velocity.x) > speed:
					current_run_state = run_state.RUNNING
					running_time = acceleration
				else:
					current_run_state = run_state.WALKING
			else:
				velocity.x = move_toward(velocity.x, 0.0 , delta * 100)

		run_state.WALKING:
			if running_time < acceleration:
				running_time += delta
			velocity.x = run_direction * speed * acceleration_curve.sample(running_time/acceleration)
			if !animating:
				run_animation.travel("walk")
			if run_direction * direction_x <= 0.0 and is_on_floor():
				current_run_state = run_state.IDLE
				running_time = 0.0
			if running_time >= acceleration and is_on_floor():
				current_run_state = run_state.RUNNING

		run_state.RUNNING:
			if !animating:
				run_animation.travel("run")
			if run_direction * direction_x <= 0.0 and is_on_floor():
				running_time = 0.0
				if current_run_state == run_state.RUNNING:
					braking_time = 0.0
					current_run_state = run_state.BRAKING
					return
			if abs(velocity.x) < speed:
				velocity.x = run_direction * speed

		run_state.BRAKING:
			run_animation.travel("walk")
			velocity.x = sign(velocity.x) * speed * deceleration_curve.sample(braking_time/deceleration)
			braking_time += delta
			if braking_time >= deceleration:
				current_run_state = run_state.WALKING
				running_time = deceleration
		
		run_state.STAGGERING:
			pass
		
		run_state.WALL_SLIDING:
			if !wall_jump.is_colliding():
				current_run_state = run_state.WALKING
		
		run_state.LEDGE_GRABBING:
			run_animation.travel("Ledge_Grab")
			coyote_timer.start(coyote_time)
			if current_action_state != action_state.IDLE_ACTION:
				current_run_state = run_state.IDLE
	direction_x = run_direction

func action_state_machine(_delta: float) -> void:
	var horizontal_direction : float = Input.get_axis("move_left", "move_right")
	var vertical_direction = Input.get_axis("move_backward", "move_forward")

	manage_action_inputs()
	match input_queued:
		inputs.JUMP:
			jump()
			return
		inputs.DASH:
			if !is_on_floor() and !dash_spent:
				input_queued = inputs.NONE
				dash(horizontal_direction, vertical_direction)
				return

	match current_action_state:
		action_state.IDLE_ACTION:
			if combo_reset_timer.is_stopped():
				combo_number = 0
			match input_queued:
				inputs.ATTACK:
					attack(horizontal_direction, vertical_direction)
					input_queued = inputs.NONE
					return
				inputs.THROW_CHILD:
					throw_grappling(horizontal_direction, vertical_direction)
					input_queued = inputs.NONE
					return
				inputs.JUMP:
					jump()
					return

		action_state.JUMPING:
			match input_queued:
				inputs.ATTACK:
					attack(horizontal_direction, vertical_direction)
					input_queued = inputs.NONE
					return
				inputs.THROW_CHILD:
					throw_grappling(horizontal_direction, vertical_direction)
					input_queued = inputs.NONE
					return
				inputs.JUMP:
					jump()
					return
		
		action_state.ATTACKING:
			match input_queued:
				inputs.JUMP:
						jump()
						return

func manage_action_inputs():
	if Input.is_action_just_pressed("Space"):
		input_queued = inputs.JUMP
		queue_timer.start(queue_time)
	if Input.is_action_just_pressed("LMB"):
		input_queued = inputs.ATTACK
		queue_timer.start(queue_time)
	if Input.is_action_just_pressed("RMB"):
		input_queued = inputs.THROW_CHILD
		queue_timer.start(queue_time)
	if Input.is_action_just_pressed("Shift"):
		input_queued = inputs.DASH
		queue_timer.start(queue_time)
	if queue_timer.is_stopped():
		input_queued = inputs.NONE

func attack(_x : float, _y : float): 
	var _attack_string : String = str("attack", combo_number)
	action_animation.travel("Robot_Punch")
	current_action_state = action_state.ATTACKING
	#set_oneshot_animation("Robot_Punch")
	combo_number = (combo_number + 1) % max_combo

func throw_grappling(x : float, y : float):
	if !carrying_child:
		alice.retract()
		return
	current_gravity_force = gravity_damp_while_hooking
	var target : Node3D = null
	
	if auto_aim.has_overlapping_bodies():
		var target_distance : float = 1000
		for i : Node3D in auto_aim.get_overlapping_bodies():
			var candidate_position : Vector3 = i.global_position
			var candidate_distance : float = candidate_position.distance_squared_to(global_position)
			if candidate_distance < target_distance:
				target = i
				target_distance = candidate_distance
	alice.global_position = 2.0 * mesh.global_basis.x + global_position
	if target != null:
		alice.throw(target.global_position)
	else:
		var target_position : Vector3 = global_position + (hookshot_range * mesh.global_basis.x.normalized())
		alice.throw(target_position)

	carrying_child = false
	set_oneshot_animation("Robot_Wave")
	
	#var position2D : Vector2 = get_tree().root.get_camera_3d().unproject_position(global_position)
	#var mouse_position : Vector2 = (get_viewport().get_mouse_position() - position2D).normalized()
	#var space_state = get_world_3d().direct_space_state
	#var origin : Vector3 = global_position
	#var end : Vector3 = hookshot_range * Vector3(mouse_position.x, -mouse_position.y, 0) + global_position
	#var query = PhysicsRayQueryParameters3D.create(origin, end)
	#query.exclude = [self]
	#var result = space_state.intersect_ray(query)
	#var target_position : Vector3
	#var target_collider : Node3D = null
	#action_animation.travel("Robot_Wave")
	#if result.is_empty():
		#target_position = end
	#else:
		#target_position = result["position"]
		#target_collider = result["collider"]
	#if global_position.distance_to(target_position) < 1.5:
		#return
	#alice.position = (target_position - global_position).normalized() * 2.0 * mesh.basis
	#alice.throw(target_position)
	#carrying_child = false

func start_grapple(_target_position : Vector3):
	current_action_state = PlayerController.action_state.FLYINGTOGRAPPLE
	hookshot_position = _target_position
	second_jump = false
	current_run_state = PlayerController.run_state.IDLE

func end_retracting() -> void:
	running_time = acceleration
	current_run_state = run_state.WALKING
	current_action_state = action_state.IDLE_ACTION
	return

func handle_gravity(delta: float) -> void:
	current_gravity_force = 1.0
	match current_run_state:
		run_state.LEDGE_GRABBING:
			current_gravity_force = 0.0
			jumping_time = jump_floatiness
		run_state.WALL_SLIDING:
			if velocity.y <= 0.0:
				current_gravity_force = wall_slide_gravity
				jumping_time = jump_floatiness

	if current_action_state == action_state.HOOKED:
		current_gravity_force = 0.0
	if jumping_time < jump_floatiness:
		jumping_time += delta
		if Input.is_action_pressed("Space"):
			velocity.y = jump_velocity
	if is_on_floor():
		second_jump = false
		dash_spent = false
		coyote_timer.start(coyote_time)
	else:
		if velocity.y < 0:
			velocity += get_gravity() * going_down_speed * 1.15 * delta * current_gravity_force
		else:
			velocity += get_gravity() * going_down_speed * 3.0 * delta * current_gravity_force

	if velocity.x < 0:
		mesh.basis = Basis.IDENTITY.rotated(mesh.basis.y,PI)
	if  velocity.x > 0:
		mesh.basis = Basis.IDENTITY

func jump() -> void:
	if !second_jump or current_run_state == run_state.WALL_SLIDING:
		input_queued = inputs.NONE
	else:
		return
	current_action_state = action_state.JUMPING
	set_oneshot_animation("Robot_Jump")
	#action_animation.travel("jump")
	#animating = true
	#action_animation.travel("Robot_Jump")
	#set_oneshot_animation("Robot_Jump", 2.0, 1.0)
	jumping_time = 0.0
	velocity.y = jump_velocity
	velocity += get_platform_velocity()
	if abs(velocity.x) > speed:
		current_run_state = run_state.RUNNING
		running_time = acceleration
	else:
		running_time = abs(velocity.x)/speed
	if coyote_timer.is_stopped():
		if current_run_state == run_state.WALL_SLIDING:
			current_action_state = action_state.BLOCKED
			current_run_state = run_state.WALKING
			var sign = 1
			if mesh.basis == Basis.IDENTITY:
				sign = -1
			velocity.x = wall_jump_repulsion * sign
			dash_reset_timer.start(wall_jump_time)
			return
		second_jump = true

func dash(horizontal_direction : float, vertical_direction : float) -> void:
	dash_spent = true
	velocity = Vector3(horizontal_direction, vertical_direction, 0).normalized() * dash_velocity
	current_action_state = action_state.BLOCKED
	dash_reset_timer.start(dash_duration)

func set_oneshot_animation(animation_name : String, time_scale : float = 1.0, _blend : float = 1.0):
	animation_tree.set("parameters/TimeScale/scale", time_scale)
	oneshot_animation.animation = animation_name
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func finish_animation():
	animating = false

func change_run_state(new_state : run_state): 
	current_run_state = new_state

func change_action_state(new_state : action_state = action_state.IDLE_ACTION):
	animation_tree.set("parameters/TimeScale/scale", 1.0)
	current_action_state = new_state
	if new_state == action_state.IDLE_ACTION:
		combo_reset_timer.start(combo_reset)
