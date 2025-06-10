extends GameTrigger

@export var progression_needed : int = 10
@export var animation_player : AnimationPlayer
@onready var label: Label = $Sprite3D/SubViewport/Panel/Label
@onready var directions: Node3D = $Sprite3D/Directions
@onready var right: Sprite3D = $Sprite3D/Directions/Right
@onready var left: Sprite3D = $Sprite3D/Directions/Left
@onready var sprite_3d: Sprite3D = $Sprite3D

var disabled : bool = false
var current_progression = 0
var current_player : Node3D

func _ready() -> void:
	label.text = str(progression_needed)
	body_entered.connect(check_for_player)
	sprite_3d.hide()

func check_for_player(body : Node3D) -> void:
	if disabled:
		return
	if body.is_in_group("player"):
		body.velocity = Vector3.ZERO
		body.current_run_state = body.run_state.IDLE
		body.current_action_state = body.action_state.INTERACTING
		body.break_interaction.connect(break_interaction)
		body.interacted.connect(interacted)
		current_player = body
		if body.last_interaction > 0.0:
			left.show()
			right.hide()
		else:
			left.hide()
			right.show()
		sprite_3d.show()

func break_interaction() -> void:
	if current_player == null:
		return
	current_player.interacted.disconnect(interacted)
	current_player.break_interaction.disconnect(break_interaction)
	current_player = null
	sprite_3d.hide()
	print_debug(current_player)

func interacted(horizontal_direction : float) -> void:
	if disabled:
		return
	current_progression += 1
	label.text = str(progression_needed - current_progression)
	if horizontal_direction > 0.0:
		left.show()
		right.hide()
	else:
		left.hide()
		right.show()
	if current_progression == progression_needed:
		current_player.current_action_state = current_player.action_state.IDLE_ACTION
		disabled = true
		break_interaction()
		animation_player.play("Cube_001Action")
		await animation_player.animation_finished
		event_triggered.emit()
