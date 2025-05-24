extends Camera3D

@onready var playerManager = get_node("../")
@onready var playerCharacter = get_node("../PlayerCharacter") as RigidBody3D

@export_subgroup("Camera Settings")
@export var cameraDepth: float = 10
@export var minDistForMaxAcceleration: float = 15
@export var cameraAccelerationCurve: Curve
@export var cameraSnapDistance: float = 0.001

@export_subgroup("Camera Weights")
@export var horizontalInputMultiplier = 0.8
@export var horizontalVelocityMultiplier = 0.1
@export var verticalVelocityMultiplier = 0.1


var targetHorizontalInput = 0.0

func _ready():
	playerManager.connect("player_horizontal_input_changed", _on_horizontal_input_changed)

func _on_horizontal_input_changed(newInput: float):
	targetHorizontalInput = newInput

func _process(delta):
	var cameraDepthOffset = Vector3.BACK * cameraDepth
	var horizontalInputOffset = Vector3.RIGHT * targetHorizontalInput * horizontalInputMultiplier
	var horizontalVelocityOffset = Vector3.RIGHT * playerCharacter.linear_velocity.x * horizontalInputMultiplier
	var verticalVelocityOffset = Vector3.UP * playerCharacter.linear_velocity.y * verticalVelocityMultiplier
	
	var targetPosition = playerCharacter.global_position + cameraDepthOffset + horizontalInputOffset + horizontalVelocityOffset + verticalVelocityOffset
	var currentToTarget = targetPosition - global_position
	var currentToTargetLength = currentToTarget.length()
	
	var step = currentToTarget.normalized() * cameraAccelerationCurve.sample(min(currentToTargetLength/minDistForMaxAcceleration, 1))
	
	if(currentToTargetLength > cameraSnapDistance):
		global_position += step
	else:
		global_position = targetPosition
	pass
