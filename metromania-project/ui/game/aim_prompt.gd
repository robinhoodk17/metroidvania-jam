extends Control

@export var interact_action : GUIDEAction
@onready var rich_text_label: RichTextLabel = $VBoxContainer/RichTextLabel

var aiming : bool = false
var aiming_at : Node3D = null
var camera : Camera3D = null

func _ready() -> void:
	call_deferred("late_ready")
	hide()

func late_ready() -> void:
	SignalbusPlayer.startedaiming.connect(start_aiming)
	SignalbusPlayer.stoppedaiming.connect(stop_aiming)

func start_aiming(_body : Node3D) -> void:
	aiming = true
	aiming_at = _body
	camera = get_viewport().get_camera_3d()
	show()
	var formatter : GUIDEInputFormatter = GUIDEInputFormatter.for_active_contexts(30)
	@warning_ignore("untyped_declaration")
	var input_label  = await formatter.action_as_richtext_async(interact_action)
	rich_text_label.text = "[center]%s[center]" % [input_label]

func stop_aiming(_body : Node3D) -> void:
	aiming = false
	aiming_at = null
	hide()

func _process(delta: float) -> void:
	if aiming and aiming_at != null and camera != null:
		global_position = camera.unproject_position(aiming_at.global_position)
