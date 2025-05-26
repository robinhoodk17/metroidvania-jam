extends CharacterBody3D
class_name alice_controller

enum run_state {IDLE, WALKING, RUNNING, BRAKING, STAGGERING}
enum action_state{IDLE_ACTION, ATTACKING, LANDING, GRAPPLING, FLYINGTOGRAPPLE, STAGGERING, HOOKED, JUMPING}
enum inputs{JUMP, ATTACK, THROW_CHILD, NONE}

@export_category("Player Movement")
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
@export var movement_to_grapple_speed : float = 20.0
@export var throw_range : float = 5.0

@export_category("Nodes")
@export var mesh : Marker3D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var queue_timer: Timer = $QueueTimer
@onready var animation_tree: AnimationTree = $AnimationTree

"""state machine"""
#var current_run_state : run_state = run_state.IDLE
#var current_action_state : action_state = action_state.IDLE_ACTION
var current_run_state : run_state = run_state.IDLE
var current_action_state : action_state = action_state.IDLE_ACTION
var off : bool = true
var direction_x : float = 0.0
var running_time : float = 0.0
var braking_time : float = 0.0
var jumping_time : float = 0.0
var second_jump : bool = false
var combo_number : int = 0
#var input_queued : inputs = inputs.NONE
var hookshot_position : Vector3
var animating : bool = false
var controllable : bool = false
var flown_distance : float = 0.0

"""animation"""
var run_animation : AnimationNodeStateMachinePlayback
var action_animation : AnimationNodeStateMachinePlayback
var oneshot_animation : AnimationNode

"""state machine"""
var input_queued : inputs = inputs.NONE

func turn_off() -> void:
	top_level = false
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, false)
	off = true
	position = Vector3.ZERO
	basis = Basis.IDENTITY
	mesh.basis = Basis.IDENTITY
	set_physics_process(false)
	second_jump = false

func turn_on() -> void:
	current_run_state = run_state.IDLE
	current_action_state = action_state.IDLE_ACTION
	off = false
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_layer_value(3, true)
	set_physics_process(true)
	top_level = true

func _ready() -> void:
	#return
	run_animation = animation_tree.get("parameters/StateMachine_running/playback")
	action_animation = animation_tree.get("parameters/StateMachine_action/playback")
	oneshot_animation = animation_tree.get_tree_root().get_node("OneShotAnimation")
	call_deferred("turn_off")

func _physics_process(delta: float) -> void:
	if off:
		return
	run_state_machine(delta)
	action_state_machine(delta)
	handle_gravity(delta)
	move_and_slide()

func run_state_machine(delta: float) -> void:
	if current_action_state == action_state.FLYINGTOGRAPPLE:
		velocity = (hookshot_position - global_position).normalized() * movement_to_grapple_speed
		run_animation.travel("idle")
		flown_distance += velocity.length() * delta
		var collisions : KinematicCollision3D = move_and_collide(velocity * delta, true)
		if collisions or flown_distance >= throw_range:
			current_action_state = action_state.IDLE_ACTION
		return
	if current_action_state == action_state.HOOKED:
		velocity = Vector3.ZERO
		run_animation.travel("idle")
		return
	var run_direction = Input.get_axis("look_left", "look_right")
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
			match input_queued:
				inputs.JUMP:
					if !second_jump:
						input_queued = inputs.NONE
						jump()
						return

func manage_action_inputs():
	if Input.is_action_just_pressed("look_up"):
		input_queued = inputs.JUMP
		queue_timer.start(queue_time)
	if queue_timer.is_stopped():
		input_queued = inputs.NONE

func jump() -> void:
	#current_action_state = action_state.JUMPING
	#action_animation.travel("jump")
	#animating = true
	set_oneshot_animation("Robot_Jump")
	#action_animation.travel("Robot_Jump")
	#set_oneshot_animation("Robot_Jump", 2.0, 1.0)
	jumping_time = 0.0
	velocity.y = jump_velocity
	if coyote_timer.is_stopped():
		second_jump = true

func throw(target_position : Vector3) -> void:
	hookshot_position = target_position
	flown_distance = 0.0
	turn_on()
	current_action_state = action_state.FLYINGTOGRAPPLE

func handle_gravity(delta: float) -> void:
	if is_on_floor():
		second_jump = false
		coyote_timer.start(coyote_time)

	if jumping_time < jump_floatiness:
		jumping_time += delta
		if Input.is_action_pressed("look_up"):
			velocity.y = jump_velocity
	if is_on_floor():
		if coyote_timer.is_stopped():
			pass
	else:
		if velocity.y < 0:
			velocity += get_gravity() * going_down_speed * 1.15 * delta
		else:
			velocity += get_gravity() * going_down_speed * 3.0 * delta

	if velocity.x < 0:
		mesh.global_basis = Basis.IDENTITY.rotated(mesh.basis.y,PI)
	if  velocity.x > 0:
		mesh.global_basis = Basis.IDENTITY

func set_oneshot_animation(animation_name : String, time_scale : float = 1.0, _blend : float = 1.0):
	animation_tree.set("parameters/TimeScale/scale", time_scale)
	oneshot_animation.animation = animation_name
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
