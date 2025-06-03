extends AudioStreamPlayer 

@export var _duration : float= 1.0
@export var max_volume := 0.05
var _tween : Tween 

@onready var Sounds : Dictionary = {"cat" : preload("res://sfx/cat.wav"), 
"EnemyCry" : preload("res://sfx/EnemyCry.wav")}

@onready var Musics:  Dictionary = {"[Idea 1] Main Theme V2" : preload("res://music/[Idea 1] Main Theme V2.mp3"),
"[Idea 2] Into the Darkness" : preload("res://music/[Idea 2] Into the Darkness.mp3")}

func _ready() -> void:
	#bus = "Music"
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
	
func play_music(track : String, duration : float = _duration) -> Signal:
	if playing:
		if stream == Musics[track]:
			return  _fade_volume(max_volume, duration)
		await _fade_volume(0, duration)
	stream = Musics[track]
	play()
	return _fade_volume(max_volume, duration)
 
func play_sfx(player: AudioStreamPlayer3D, clip_key: String) -> void:
	if Sounds.has(clip_key) == false:
		return
	player.stream = Sounds[clip_key]
	player.play()
 
