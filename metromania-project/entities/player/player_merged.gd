extends RigidBody3D
enum upper_state {ATTACKING, LOCOMOTION, JUMPING, LANDING}
enum lower_state{IDLE_LOWER}

@export_category("Player Movement")
@export var jump_impulse : float = 13.0
@export var jump_floatiness : float = 0.5
@export var going_down_speed : float = 2.0
@export_subgroup("Horizontal Movement")
@export var horizontalMaxSpeed: float = 10
@export var horizontalInputSnap: float = 25
@export var horizontalAccelerationMultiplier: float = 25
@export var horizontalAccelerationCurve: Curve
@export var coyote_time : float = 0.15
@export var landing_time : float = 0.25
@export_category("Camera")
@export var dampen_frames : int = 20
@export_category("Nodes")
@export var mesh : Marker3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var landing_timer: Timer = $LandingTimer
@onready var player_ground_cast: RayCast3D = $MeshParent/PlayerGroundCast
@onready var animation_tree: AnimationTree = $AnimationTree

var current_up_state : upper_state = upper_state.LOCOMOTION
var current_low_state : lower_state = lower_state.IDLE_LOWER

var horizontalInput = 0.0
var targetHorizontalInput = 0.0
var horizontalForce = Vector3.ZERO
var verticalForce  = Vector3.ZERO
var second_jump : bool = false

var dampened_y_array : Array[float]
var averaged_y : float
var current_y : int = 0
var grounded : bool = false

"""animation"""
var upper_animation : AnimationNodeStateMachinePlayback
var lower_animation : AnimationNodeStateMachinePlayback
var locomotion : AnimationNodeStateMachinePlayback
var oneshot_animation : AnimationNode

func _ready() -> void:
	"""setting up animations"""
	upper_animation = animation_tree.get("parameters/StateMachine_upper/playback")
	lower_animation = animation_tree.get("parameters/StateMachine_lower/playback")
	oneshot_animation = animation_tree.get_tree_root().get_node("OneShotAnimation")
	locomotion = animation_tree.get("parameters/StateMachine_upper/locomotion/playback")

	for i : int in range(dampen_frames):
		dampened_y_array.append(global_position.y)
		averaged_y = global_position.y

func _physics_process(delta: float) -> void:
	if linear_velocity.x < 0:
		mesh.basis = Basis.FLIP_X
	if  linear_velocity.x > 0:
		mesh.basis = Basis.IDENTITY
	if Input.is_action_just_pressed("Space") and !second_jump:
		jump()
	position_camera(delta)
	state_machine(delta)
	handle_gravity(delta)

func state_machine(delta) -> void:
	horizontal_movement(delta)
	match current_up_state:
		upper_state.LOCOMOTION:
			upper_animation.travel("locomotion")
			animation_tree.set("parameters/StateMachine_upper/locomotion/BlendSpace1D/blend_position", abs(linear_velocity.x)/horizontalMaxSpeed - 1.0)
		upper_state.JUMPING:
			pass

func horizontal_movement(delta) -> void:
	targetHorizontalInput = Input.get_axis("move_left", "move_right")
	var horizontalAcceleration = horizontalAccelerationCurve.sample(abs(horizontalInput - targetHorizontalInput)/2) * horizontalAccelerationMultiplier
	horizontalInput = move_toward(targetHorizontalInput, horizontalInput, horizontalInputSnap * delta)
	if !landing_timer.is_stopped():
		horizontalAcceleration *= 40.0
	var targetHorizontalForce = Vector3(targetHorizontalInput * horizontalMaxSpeed,0,0)
	horizontalForce = horizontalForce.move_toward(targetHorizontalForce, horizontalAcceleration * delta)
	
	apply_central_force(horizontalForce + verticalForce - linear_velocity)

func handle_gravity(delta) -> void:
	if player_ground_cast.is_colliding():
		grounded = true
		coyote_timer.start(coyote_time)
		
	else:
		landing_timer.start(landing_time)
		grounded = false
		if linear_velocity.dot(mesh.global_basis.y) > 0.0:
			apply_central_force(-mesh.global_basis.y * get_gravity().length() * .1)
	apply_central_force(-mesh.global_basis.y * get_gravity().length())
	
	if Input.is_action_pressed("Space") and linear_velocity.dot(mesh.global_basis.y) > 0.0 and !grounded:
		apply_central_force(mesh.global_basis.y * jump_impulse * 3.5)

func jump() -> void:
	current_up_state = upper_state.JUMPING
	upper_animation.travel("jump")
	#set_oneshot_animation("Robot_Jump",1.0,0.5)
	if linear_velocity.dot(mesh.global_basis.y) < 0.0:
		apply_central_impulse(-linear_velocity.y * mass * mesh.global_basis.y)
	apply_central_impulse(mesh.global_basis.y * jump_impulse)
	if coyote_timer.is_stopped():
		second_jump = true

func position_camera(delta: float) -> void:
	current_y = (current_y + 1) % dampened_y_array.size()
	dampened_y_array[current_y] = global_position.y
	var running_sum : float = 0.0
	for i : float in dampened_y_array:
		running_sum += i
	averaged_y = running_sum/dampened_y_array.size()
	if grounded:
		second_jump = false
		coyote_timer.start(coyote_time)
		camera_pivot.global_position = lerp(camera_pivot.global_position, global_position, 5.0 * delta)
	else:
		var target_position = Vector3(global_position.x, averaged_y, global_position.z)
		camera_pivot.global_position = lerp(camera_pivot.global_position, target_position, 2.5 * delta)

func set_oneshot_animation(animation_name : String, time_scale : float = 1.0, blend : float = 1.0):
	animation_tree.set("parameters/TimeScale/scale", time_scale)
	oneshot_animation.animation = animation_name
	animation_tree.set("parameters/OneShotBlend/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func change_upper_state(new_state : upper_state): 
	current_up_state = new_state
