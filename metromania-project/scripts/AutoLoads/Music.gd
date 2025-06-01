extends AudioStreamPlayer 

@export var _duration : float= 1.0

var _tween : Tween 
var Sounds : Dictionary

func _ready() -> void:
	Sounds = preload_items_from_folder("res://sfx/")
	bus = "Music"
	set_linear_volume(0)
	process_mode = Node.PROCESS_MODE_ALWAYS
 
func set_linear_volume(linear_volume : float) -> void:
	volume_db = linear_to_db(linear_volume) 
	
func _fade_volume(target_volume: float, duration : float = _duration) -> Signal:
	if _tween && _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(set_linear_volume, db_to_linear(volume_db) , target_volume, duration)
	return _tween.finished

func fade_out(duration : float = _duration) -> void:
	await _fade_volume(0, duration) 
	stop()
	stream = null
	
func play_music(track : AudioStream, duration : float = _duration) -> Signal:
	if playing:
		if stream == track:
			return  _fade_volume(1, duration)
		await _fade_volume(0, duration)
	stream = track
	play()
	return _fade_volume(1, duration)
 
func play_sfx(player: AudioStreamPlayer3D, clip_key: String) -> void:
	if Sounds.has(clip_key) == false:
		return
	player.stream = Sounds[clip_key]
	player.play()

func preload_items_from_folder(folder_path: String) -> Dictionary:
	var dir = DirAccess.open(folder_path)
	var resources : Dictionary = {}
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() && not file_name.ends_with("import"):
				var file_path = folder_path + file_name
				var res = ResourceLoader.load(file_path)
				if res:
					var key = file_name.get_basename()
					resources[key] = res
				else:
					push_warning("Failed to load resource: %s" % file_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Cannot open directory: %s" % folder_path)
	return resources
