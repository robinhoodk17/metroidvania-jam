extends Node

# What goes into utils.gd?
# If the function is completely independent of the game, it's probably a utility.
# If not, it (probably) belongs in globals.gd

func start_dialogue(timeline : String) -> void:
	get_tree().paused = true
	if DialogicResourceUtil.get_timeline_resource(timeline) == null:
		print_debug("timeline missing:  ", timeline)
		Dialogic.start("whoops")
		return
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		Dialogic.start(timeline).process_mode = Node.PROCESS_MODE_ALWAYS
		Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
		Dialogic.timeline_ended.connect(func(): get_tree().paused = false)

func reparent_node(node: Node, parent: Node, position_reset: bool = true) -> void:
	if not is_instance_valid(node):
		return
	var pos: Variant = node.get("global_position")

	var old_parent: Node = node.get_parent()
	if is_instance_valid(old_parent):
		old_parent.call_deferred("remove_child", node)
		await get_tree().process_frame
	if position_reset:
		node.set("position", Vector2.ZERO)
	if is_instance_valid(parent):
		parent.add_child(node)
	# Is the 2nd await required or could we set_deferred instead?
	# Or is no delay needed at all?
	# await get_tree().process_frame
	if position_reset and pos:
		node.set("global_position", pos)

func change_scene(new_scene : String,  _player : PlayerController, entrance_number : int = 0) -> void:
	await Ui.fade_to_black(0.2)
	await get_tree().change_scene_to_file(new_scene)
	await get_tree().create_timer(.01).timeout
	SignalbusPlayer.entered_level.emit(entrance_number)
	if _player != null:
		%Myck.velocity = _player.velocity
	await Ui.fade_to_clear(0.2)
