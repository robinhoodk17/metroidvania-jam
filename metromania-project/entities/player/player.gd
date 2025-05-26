extends CharacterBody3D
class_name PlayerController

enum run_state {IDLE, WALKING, RUNNING, BRAKING, STAGGERING}
enum action_state{IDLE_ACTION, ATTACKING, LANDING, GRAPPLING, FLYINGTOGRAPPLE, STAGGERING, HOOKED, JUMPING}
enum inputs{JUMP, ATTACK, THROW_CHILD, NONE}

@export_group("Player Movement")
@export var speed : float = 10.0
@export var jump_velocity : float = 13.0
@export var jump_floatiness : float = 0.15
@export var going_down_speed : float = 3.0
@export var acceleration_curve : Curve
@export var deceleration_curve : Curve
##the number of seconds required to accelerate from 0 to max speed
@export var acceleration : float = 0.7
##the number of seconds required to brake from max to 0
@export var deceleration : float = .15
@export var coyote_time : float = 0.1
@export var queue_time : float = 0.35
@export_group("Combat")
@export var combo_reset : float = 1.5
@export var max_combo : int = 3
@export_group("Hookshot")
@export var hookshot_range : float = 25.0
@export var movement_to_grapple_speed : float = 40.0
@export var gravity_damp_while_hooking : float = 0.25
@export_group("Camera")
@export var dampen_frames : int = 20
@export_group("Nodes")
@export var mesh : Marker3D

@onready var camera_pivot: Node3D = $CameraPivot
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var combo_reset_timer: Timer = $ComboResetTimer
@onready var queue_timer: Timer = $QueueTimer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var grappling_hook : Node3D = $GrapplingHookParent

"""child interaction"""
@onready var alice: CharacterBody3D = $MeshParent/ChildContainer/Alice
@onready var pick_child: Area3D = $MeshParent/PickChild

"""state machine"""
var current_run_state : run_state = run_state.IDLE
var current_action_state : action_state = action_state.IDLE_ACTION

var carrying_child : bool = true
var direction_x : float = 0.0
var running_time : float = 0.0
var braking_time : float = 0.0
var jumping_time : float = 0.0
var second_jump : bool = false
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
	pick_child.connect("body_entered",pick_up_child)
	screen_middle = DisplayServer.screen_get_size()/2
	"""setting up animations"""
	run_animation = animation_tree.get("parameters/StateMachine_running/playback")
	action_animation = animation_tree.get("parameters/StateMachine_action/playback")
	oneshot_animation = animation_tree.get_tree_root().get_node("OneShotAnimation")
	for i : int in range(dampen_frames):
		dampened_y_array.append(global_position.y)
		averaged_y = global_position.y

func pick_up_child(_body : Node3D):
	if _body.is_in_group("Player"):
		_body.turn_off()
		carrying_child = true

func _physics_process(delta: float) -> void:
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
		second_jump = false
		coyote_timer.start(coyote_time)
		camera_pivot.global_position = lerp(camera_pivot.global_position, global_position, 5.0 * delta)
	else:
		var target_position = Vector3(global_position.x, averaged_y, global_position.z)
		camera_pivot.global_position = lerp(camera_pivot.global_position, target_position, 2.5 * delta)

func run_state_machine(delta: float) -> void:
	if current_action_state == action_state.FLYINGTOGRAPPLE:
		velocity = (hookshot_position - global_position).normalized() * movement_to_grapple_speed
		run_animation.travel("idle")
	if current_action_state == action_state.HOOKED:
		velocity = Vector3.ZERO
		run_animation.travel("idle")
		return
	var run_direction = Input.get_axis("move_left", "move_right")
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
	direction_x = run_direction

func action_state_machine(_delta: float) -> void:
	var horizontal_direction : float = Input.get_axis("move_left", "move_right")
	var vertical_direction = Input.get_axis("move_backward", "move_forward")

	manage_action_inputs()
	match input_queued:
		inputs.JUMP:
			if !second_jump:
				input_queued = inputs.NONE
				jump()
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
					if !second_jump:
						input_queued = inputs.NONE
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
					if !second_jump:
						input_queued = inputs.NONE
						jump()
						return
		
		action_state.ATTACKING:
			match input_queued:
				inputs.JUMP:
					if !second_jump:
						input_queued = inputs.NONE
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
		alice.turn_off()
		carrying_child = true
		return
	current_gravity_force = gravity_damp_while_hooking
	var position2D : Vector2 = get_tree().root.get_camera_3d().unproject_position(global_position)
	var mouse_position : Vector2 = (get_viewport().get_mouse_position() - position2D).normalized()
	var space_state = get_world_3d().direct_space_state
	var origin : Vector3 = global_position
	var end : Vector3 = hookshot_range * Vector3(mouse_position.x, -mouse_position.y, 0) + global_position
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	var target_position : Vector3
	var target_collider : Node3D = null
	action_animation.travel("Robot_Wave")
	if result.is_empty():
		target_position = end
	else:
		target_position = result["position"]
		target_collider = result["collider"]
	if global_position.distance_to(target_position) < 1.5:
		return
	alice.position = (target_position - global_position).normalized() * 2.0 * mesh.basis
	alice.throw(target_position)
	carrying_child = false
	#current_action_state = action_state.GRAPPLING
	#grappling_hook.hookshot_range = hookshot_range
	#grappling_hook.start_hooking(global_position, target_position, target_collider)

func end_retracting(_hooked : bool) -> void:
	if _hooked:
		change_action_state(PlayerController.action_state.HOOKED)
		running_time = acceleration
		current_run_state = run_state.WALKING
		velocity/= 2.0
		current_gravity_force = 0.0
		return
	current_action_state = action_state.IDLE_ACTION

func handle_gravity(delta: float) -> void:
	current_gravity_force = 1.0
	if current_action_state == action_state.HOOKED:
		current_gravity_force = 0.0
	if jumping_time < jump_floatiness:
		jumping_time += delta
		if Input.is_action_pressed("Space"):
			velocity.y = jump_velocity
	if is_on_floor():
		if coyote_timer.is_stopped():
			pass
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
	current_action_state = action_state.JUMPING
	#action_animation.travel("jump")
	#animating = true
	action_animation.travel("Robot_Jump")
	#set_oneshot_animation("Robot_Jump", 2.0, 1.0)
	jumping_time = 0.0
	velocity.y = jump_velocity
	if coyote_timer.is_stopped():
		second_jump = true

func set_oneshot_animation(animation_name : String, time_scale : float = 1.0, _blend : float = 1.0):
	animation_tree.set("parameters/TimeScale/scale", time_scale)
	oneshot_animation.animation = animation_name
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func finish_animation():
	animating = false

func change_run_state(new_state : run_state): 
	current_run_state = new_state

func change_action_state(new_state : action_state):
	animation_tree.set("parameters/TimeScale/scale", 1.0)
	current_action_state = new_state
	if new_state == action_state.IDLE_ACTION:
		combo_reset_timer.start(combo_reset)
