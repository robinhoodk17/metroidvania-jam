extends GameTrigger

@export var progression_needed : int = 10
@export var animation_player : AnimationPlayer
@onready var label: Label = $Sprite3D/SubViewport/Panel/Label

var disabled : bool = false
var current_progression = 0
var current_player : Node3D

func _ready() -> void:
	label.text = str(progression_needed)
	body_entered.connect(check_for_player)
	animation_player.animation_finished.connect(event_triggered.emit)

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
		event_triggered.emit()

func break_interaction() -> void:
	if current_player == null:
		return
	current_player.interacted.disconnect(interacted)
	current_player.break_interaction.disconnect(break_interaction)
	current_player = null
	print_debug(current_player)

func interacted() -> void:
	if disabled:
		return
	current_progression += 1
	label.text = str(progression_needed - current_progression)
	if current_progression == progression_needed:
		current_player.current_action_state = current_player.action_state.IDLE_ACTION
		disabled = true
		break_interaction()
		animation_player.play("Cube_001Action")
