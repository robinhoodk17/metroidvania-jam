extends AudioStreamPlayer 

@export var _duration : float= 1.0
@export var max_volume := 0.05
var _tween : Tween 

@onready var Sounds : Dictionary 
@onready var Musics:  Dictionary = {"[Idea 1] Main Theme V2" : preload("res://music/[Idea 1] Main Theme V2.mp3"),
"[Idea 2] Into the Darkness" : preload("res://music/[Idea 2] Into the Darkness.mp3")}

func _ready() -> void:
	Sounds = {"attack1" : preload("res://sfx/attack1.wav"),
	"attack2" : preload("res://sfx/attack2.wav"),
	"attack3-uppercut" : preload("res://sfx/attack3-uppercut.wav"),
	"attack4-slam" : preload("res://sfx/attack4-slam.wav"),
	"footstep1" : preload("res://sfx/footstep1.wav"), 
	"footstep2" : preload("res://sfx/footstep2.wav"),
	"footstep3" : preload("res://sfx/footstep3.wav"),
	"footstep4" : preload("res://sfx/footstep4.wav"),
	"footstep5" : preload("res://sfx/footstep5.wav"),
	"footstep6" : preload("res://sfx/footstep6.wav"),
	"hit" : preload("res://sfx/hit.wav"),
	"jump1" : preload("res://sfx/jump1.wav"),
	"jump2" : preload("res://sfx/jump2.wav"),
	"jump3" : preload("res://sfx/jump3.wav"),
	"jump4" : preload("res://sfx/jump4.wav"),
	"land" : preload("res://sfx/land.wav")
	}
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
 
