extends RigidBody3D

@onready var playerManager = get_node("../")

@export_subgroup("Horizontal Movement")
@export var horizontalMaxSpeed: float = 10
@export var horizontalInputSnap: float = 25
@export var horizontalAccelerationMultiplier: float = 25
@export var horizontalAccelerationCurve: Curve

@export_subgroup("Vertical Ground Distances")
@export var idealGroundDist: float = 0.5
@export var minGroundDist: float = 0.25
@export var maxGroundDist: float = 0.75

@export_subgroup("Vertical Spring-Damper")
@export var verticalSpring: float = 1000
@export var verticalDampen: float = 10

@export_subgroup("Jumping")
# For now, setting jump direction to Up for all cases. 
# In the future, we could do wall jumps or running jumps by changing this value.
var jumpDirection = Vector3.UP
@export var jumpImpulseForce: float = 3
@export var jumpFloatForce: float = 5


@onready var groundCast = get_node("PlayerGroundCast") as RayCast3D
@onready var jumpCooldownTimer = get_node("JumpCooldownTimer") as Timer
@onready var coyoteTimer = get_node("CoyoteTimer") as Timer
@onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * ProjectSettings.get_setting("physics/3d/default_gravity")

var grounded = false

var horizontalInput = 0.0
var targetHorizontalInput = 0.0

var horizontalForce = Vector3.ZERO
var verticalForce  = Vector3.ZERO

func _ready():
	groundCast.target_position.y = -maxGroundDist
	playerManager.connect("player_horizontal_input_changed", _on_horizontal_input_changed)
	playerManager.connect("player_space_pressed", _on_space_pressed)
	pass

func _on_horizontal_input_changed(newInput: float):
	targetHorizontalInput = newInput
	
func _on_space_pressed():
	if (groundCast.is_colliding() || !coyoteTimer.is_stopped()) && jumpCooldownTimer.is_stopped():
		jumpCooldownTimer.start()
		
		grounded = false
		if !coyoteTimer.is_stopped():
			coyoteTimer.stop()
		
		linear_velocity.y = 0
		verticalForce = jumpDirection * jumpFloatForce
		apply_central_impulse(jumpDirection * jumpImpulseForce)

func _physics_process(delta):	
	# Vector of the ground cast ray's origin to the ground.
	var originToGround = groundCast.get_collision_point() - groundCast.global_position
	var distToGround = originToGround.length()	
	
	if grounded:
		if !groundCast.is_colliding():
			grounded = false
			coyoteTimer.start()
	else:
		if (groundCast.is_colliding() && distToGround <= minGroundDist):
			grounded = true
			coyoteTimer.stop()
			
			linear_velocity.y = 0
			
	if grounded:
		verticalForce = -originToGround.normalized() * ((idealGroundDist - distToGround) * verticalSpring - verticalDampen) * delta
	else:
		verticalForce += gravity * delta
	
	verticalForce = Vector3(0,verticalForce.y,0)

	var horizontalAcceleration = horizontalAccelerationCurve.sample(abs(horizontalInput - targetHorizontalInput)/2) * horizontalAccelerationMultiplier
	horizontalInput = move_toward(targetHorizontalInput, horizontalInput, horizontalInputSnap * delta)
	
	var targetHorizontalForce = Vector3(targetHorizontalInput * horizontalMaxSpeed,0,0)
	horizontalForce = horizontalForce.move_toward(targetHorizontalForce, horizontalAcceleration * delta)
	print_debug(horizontalForce)
	apply_central_force(horizontalForce + verticalForce - linear_velocity)
