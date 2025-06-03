extends Sprite3D

@export var interact_action : GUIDEAction = null
@export var message : String = "Jump"

@onready var message_label: Label = $SubViewport/VBoxContainer/Message
@onready var prompt: RichTextLabel = $SubViewport/VBoxContainer/Prompt
@onready var sub_viewport: SubViewport = $SubViewport

var aiming : bool = false
var aiming_at : Node3D = null
var camera : Camera3D = null

func _ready() -> void:
	GUIDE.input_mappings_changed.connect(update)
	message_label.text = message
	texture = sub_viewport.get_texture()
	call_deferred("update")

func update() -> void:
	if interact_action == null:
		prompt.hide()
		return
	var formatter : GUIDEInputFormatter = GUIDEInputFormatter.for_active_contexts(200)
	var input_label  = await formatter.action_as_richtext_async(interact_action)
	prompt.text = "[center]%s[center]" % [input_label]
