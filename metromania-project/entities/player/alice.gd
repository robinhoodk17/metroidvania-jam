extends CharacterBody3D
class_name alice_controller

enum run_state {IDLE, WALKING, RUNNING, BRAKING, WALL_SLIDING, STAGGERING, LEDGE_GRABBING}
enum action_state{IDLE_ACTION, ATTACKING, LANDING, GRAPPLING, FLYINGTOGRAPPLE, JUMPING, BLOCKED, DASHING, INTERACTING, HOOKED}
enum inputs{JUMP, ATTACK, THROW_CHILD, DASH, NONE}

signal interacted
signal break_interaction

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
@export var movement_to_grapple_speed : float = 20.0
@export var throw_range : float = 5.0

@export_subgroup("wall jump")
##the velocity in x repulsing the player from the wall
@export var wall_jump_repulsion : float = 10.0
@export var wall_jump_time : float = 0.25
##when the player is pressing against a wall, how much it stops falling
@export var wall_slide_gravity : float = 0.2
@export var dash_velocity : float = 30.0
@export var dash_duration : float = 0.35
@export var ledge_grab_offset : float = -.125
@export var wall_jump_freeze : float = 0.25

@export_group("Combat")
@export var combo_reset : float = 1.5
@export var max_combo : int = 3
@export var stagger_speed : float = 20.0

@export_group("Nodes")
@export var mesh : Marker3D
@export var left_right : GUIDEAction
@export var up_down : GUIDEAction
@export var jump_action : GUIDEAction
@export var dash_action : GUIDEAction
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var dash_reset_timer: Timer = $DashResetTimer
@onready var combo_reset_timer: Timer = $ComboResetTimer
@onready var queue_timer: Timer = $QueueTimer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var wall_jump: ShapeCast3D = $MeshParent/MeshChild/WallJump
@onready var ledge_grab: RayCast3D = $MeshParent/MeshChild/LedgeGrab
@onready var check_collisions: RayCast3D = $MeshParent/MeshChild/LedgeGrab/CheckCollisions
@onready var hurt_box: Area3D = $MeshParent/MeshChild/HurtBox
@onready var wall_jump_freeze_timer: Timer = $"../../../WallJumpFreezeTimer"

"""state machine"""
#var current_run_state : run_state = run_state.IDLE
#var current_action_state : action_state = action_state.IDLE_ACTION
var current_run_state : run_state = run_state.IDLE

var current_action_state : action_state = action_state.IDLE_ACTION : 
	set(value):
		if current_action_state == action_state.INTERACTING:
			break_interaction.emit()
		current_action_state = value

"""state machine"""
var input_queued : inputs = inputs.NONE
var last_interaction : float = -1.0
var dash_spent : bool = false
var off : bool = true
var direction_x : float = 0.0
var running_time : float = 0.0
var braking_time : float = 0.0
var jumping_time : float = 0.0
var second_jump : bool = false
var combo_number : int = 0
var retracting : bool = false
var hookshot_position : Vector3
var animating : bool = false
var current_gravity_force : float = 1.0

var staggering_towards : Vector3
var staggering_distance : float
var traveled_stagger_distance : float
var controllable : bool = false
var flown_distance : float = 0.0
var airborne : bool = false

"""animation"""
var run_animation : AnimationNodeStateMachinePlayback
var action_animation : AnimationNodeStateMachinePlayback
var oneshot_animation : AnimationNode



func turn_off() -> void:
	SignalbusPlayer.child_picked_up.emit()
	if retracting:
		SignalbusPlayer.end_retracting.emit()
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
	retracting = false
	current_run_state = run_state.IDLE
	current_action_state = action_state.IDLE_ACTION

func retract() -> void:
	if current_action_state == action_state.HOOKED:
		SignalbusPlayer.start_grapple.emit(global_position)
		retracting = true
		return
	turn_off()

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
	hurt_box.body_entered.connect(check_body)
	run_animation = animation_tree.get("parameters/StateMachine_running/playback")
	action_animation = animation_tree.get("parameters/StateMachine_action/playback")
	oneshot_animation = animation_tree.get_tree_root().get_node("OneShotAnimation")
	dash_reset_timer.timeout.connect(change_action_state)
	call_deferred("turn_off")

func _physics_process(delta: float) -> void:
	if off:
		return
	run_state_machine(delta)
	action_state_machine(delta)
	handle_gravity(delta)
	move_and_slide()

func run_state_machine(delta: float) -> void:
	if current_action_state == action_state.INTERACTING:
		return
	if current_run_state == run_state.STAGGERING:
		velocity = staggering_towards * stagger_speed
		traveled_stagger_distance += stagger_speed * delta
		if traveled_stagger_distance > staggering_distance:
			current_run_state = run_state.IDLE
		return

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
		
	var run_direction = left_right.value_axis_1d
	var vertical_direction = up_down.value_axis_1d
	var aiming_for_wall : bool = false
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
		aiming_for_wall = run_direction * mesh.global_basis.z.z > 0
		#print_debug("overlapping bodies and not ledge grab ", current_action_state)
		if aiming_for_wall and !is_on_floor():
			#print_debug("facing and pressing button")
			if current_run_state != run_state.WALL_SLIDING:
				if velocity.y < 0:
					velocity.y = 0
					wall_jump_freeze_timer.start(wall_jump_freeze)
			current_run_state = run_state.WALL_SLIDING
			#print_debug("wall sliding")
	
	if current_action_state == action_state.BLOCKED:
		return
	if current_action_state == action_state.DASHING:
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
			if abs(velocity.x) < speed:
				velocity.x = run_direction * speed * acceleration_curve.sample(running_time/acceleration)
			else:
				velocity.x = abs(velocity.x) * run_direction
			if !animating:
				run_animation.travel("walk")
			if run_direction * direction_x <= 0.0 and is_on_floor():
				current_run_state = run_state.IDLE
				running_time = 0.0
			if running_time >= acceleration and is_on_floor():
				current_run_state = run_state.RUNNING

		run_state.RUNNING:
			if !is_on_floor():
				current_run_state = run_state.WALKING
			if !animating:
				run_animation.travel("run")
			if run_direction * direction_x <= 0.0 and is_on_floor():
				running_time = 0.0
				braking_time = 0.0
				current_run_state = run_state.BRAKING
				return
			if abs(velocity.x) < speed:
				velocity.x = run_direction * speed
			else:
				velocity.x = move_toward(velocity.x, sign(velocity.x) * speed, delta * 5.0)

		run_state.BRAKING:
			run_animation.travel("walk")
			velocity.x = sign(velocity.x) * speed * deceleration_curve.sample(braking_time/deceleration)
			braking_time += delta
			if braking_time >= deceleration:
				current_run_state = run_state.WALKING
				running_time = deceleration

		run_state.WALL_SLIDING:
			if !wall_jump.is_colliding() or is_on_floor():
				current_run_state = run_state.WALKING
		
		run_state.LEDGE_GRABBING:
			run_animation.travel("Ledge_Grab")
			coyote_timer.start(coyote_time)
			if current_action_state != action_state.IDLE_ACTION:
				current_run_state = run_state.IDLE
	direction_x = run_direction

func action_state_machine(_delta: float) -> void:
	var horizontal_direction : float = left_right.value_axis_1d
	var vertical_direction : float = up_down.value_axis_1d

	manage_action_inputs()
	if current_run_state == run_state.STAGGERING:
		return

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
				inputs.JUMP:
					jump()
					return

		action_state.JUMPING:
			match input_queued:
				inputs.JUMP:
					jump()
					return
		
		action_state.DASHING:
			if is_on_floor():
				current_action_state = action_state.IDLE_ACTION
		
		action_state.INTERACTING:
			if horizontal_direction * last_interaction < 0.0:
				last_interaction = horizontal_direction
				interacted.emit(horizontal_direction)

func manage_action_inputs():
	if jump_action.is_triggered():
		input_queued = inputs.JUMP
		queue_timer.start(queue_time)
	if queue_timer.is_stopped():
		input_queued = inputs.NONE

func dash(horizontal_direction : float, vertical_direction : float) -> void:
	if horizontal_direction == 0.0 and vertical_direction == 0.0:
		horizontal_direction = mesh.global_basis.z.z
	dash_spent = true
	velocity = Vector3(horizontal_direction, vertical_direction, 0).normalized() * dash_velocity
	current_action_state = action_state.DASHING
	current_run_state = run_state.RUNNING
	running_time = acceleration
	dash_reset_timer.start(dash_duration)
	
func jump() -> void:
	if !second_jump or current_run_state == run_state.WALL_SLIDING:
		input_queued = inputs.NONE
	else:
		return
	current_action_state = action_state.JUMPING
	set_oneshot_animation("Robot_Jump")
	jumping_time = 0.0
	velocity.y = jump_velocity
	velocity += get_platform_velocity()/4.0
	if abs(velocity.x) > speed:
		running_time = acceleration
	else:
		running_time = abs(velocity.x)/speed
	
	if coyote_timer.is_stopped():
		if current_run_state == run_state.WALL_SLIDING:
			do_wall_jump()
			return
		second_jump = true

func do_wall_jump() -> void:
	current_action_state = action_state.BLOCKED
	current_run_state = run_state.WALKING
	var _sign = 1
	if mesh.basis == Basis.IDENTITY:
		_sign = -1
	velocity.x = wall_jump_repulsion * _sign
	dash_reset_timer.start(wall_jump_time)

##the function to get thrown by Quackbit
func throw(target_position : Vector3) -> void:
	throw_range = global_position.distance_to(target_position)
	hookshot_position = target_position
	flown_distance = 0.0
	turn_on()
	current_action_state = action_state.FLYINGTOGRAPPLE

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
	
	if !wall_jump_freeze_timer.is_stopped():
		current_gravity_force = 0.0

	if current_action_state == action_state.HOOKED:
		current_gravity_force = 0.0
	if jumping_time < jump_floatiness:
		jumping_time += delta
		if jump_action.value_bool:
			velocity.y = jump_velocity
	if is_on_floor():
		second_jump = false
		dash_spent = false
		if airborne:
			velocity.x *= .8
		airborne = false
		coyote_timer.start(coyote_time)
	else:
		airborne = true
		if velocity.y < 0:
			velocity += get_gravity() * going_down_speed * 1.15 * delta * current_gravity_force
		else:
			velocity += get_gravity() * going_down_speed * 3.0 * delta * current_gravity_force

	if velocity.x < 0:
		mesh.global_basis = Basis.IDENTITY.rotated(mesh.basis.y,PI)
	if  velocity.x > 0:
		mesh.global_basis = Basis.IDENTITY

func set_oneshot_animation(animation_name : String, time_scale : float = 1.0, _blend : float = 1.0):
	animation_tree.set("parameters/TimeScale/scale", time_scale)
	oneshot_animation.animation = animation_name
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func change_action_state(new_state : action_state = action_state.IDLE_ACTION):
	animation_tree.set("parameters/TimeScale/scale", 1.0)
	current_action_state = new_state

func check_body(body : Node3D):
	if off:
		return
	if body.is_in_group("hook"):
		SignalbusPlayer.grabbed_hook.emit()
		current_action_state = action_state.HOOKED
		current_run_state = run_state.IDLE
		#current_action_state = action_state.IDLE_ACTION
	if body.is_in_group("player") and body != self:
		if current_action_state == action_state.HOOKED:
			if body.current_action_state == body.action_state.FLYINGTOGRAPPLE:
				turn_off()
			return
		turn_off()
