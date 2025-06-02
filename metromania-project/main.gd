extends Node
 
const CLEAR : Color = Color(0,0,0,0)
var _tween: Tween
var tween2: Tween
var fade : ColorRect
@export var fade_duration := 1.0
@export var musics : Array[AudioStream]
@onready var canvas_layer: CanvasLayer = $CanvasLayer
const HEALTH_BAR_FILL = preload("res://peyman/Health bar fill.png")
const HEALTH_BAR_OUTLINE = preload("res://peyman/Health bar outline.png")
var progress_bar: TextureProgressBar

func _ready() -> void:
	call_deferred("late_ready")
	create_fade()
	create_progress_bar()
	create_sun_envio()
	if SaveLoad.progress == null:
		SaveLoad.progress = Progress.new()
		print("progress resource created")
	if musics.size() > 0:
		Music.play_music(musics[0])
	progress_bar.hide()
	await fade_to_clear()
	set_progress_bar_value(50)
 
func late_ready() -> void:
	Ui.show_ui("MainMenu")
	await get_tree().create_timer(5).timeout

func play_different_music (int):
	match int:
		0:
			Music.play_music(musics[0])
		1: 
			Music.play_music(musics[1])
		2:
			pass

func set_progress_bar_value(amount: float) -> void:
	var max_value = progress_bar.max_value
	var clamped_amount = clamp(amount, 0, max_value)
	if tween2 && tween2.is_running():
		tween2.Kill()
	tween2 = create_tween()
	tween2.tween_property(progress_bar, "value", clamped_amount, 0.3)
	
func change_scenes(path : String) -> void:
	Music.fade_out()
	await fade_to_black()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
 
func reload_cur_scene() -> void:
	Music.fade_out()
	await fade_to_black()
	get_tree().paused = false
	get_tree().reload_current_scene()
 

#region create_nodes

func create_fade() -> void:
	fade = ColorRect.new()
	fade.name = "fade"
	fade.color = Color.BLACK 
	fade.anchor_left = 0
	fade.anchor_top = 0
	fade.anchor_right = 1
	fade.anchor_bottom = 1
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade)

func create_progress_bar():
	progress_bar = TextureProgressBar.new()
	progress_bar.name = "XPProgressBar"
	progress_bar.scale *= 0.4
	progress_bar.texture_over = HEALTH_BAR_OUTLINE
	progress_bar.texture_progress = HEALTH_BAR_FILL
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.set_position(Vector2(25.0, 25.0)) 
	canvas_layer.add_child(progress_bar)
 
func create_sun_envio():
	var sun : DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.8)  
	sun.light_energy = 0.8
	sun.light_indirect_energy = 0.5 
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05 
	sun.shadow_normal_bias = 0.8
	sun.shadow_blur = 2.0 
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var environment : Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.8, 1.0)  
	environment.ambient_light_color = Color(0.3, 0.35, 0.4)
	environment.ambient_light_energy = 0.8
	environment.ambient_light_sky_contribution = 0.5
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.6, 0.8, 1.0)
	environment.fog_depth_begin = 10.0
	environment.fog_depth_end = 50.0
	var world_env : WorldEnvironment = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	environment.glow_strength = 0.5

#endregion

func fade_to_clear(duration: float = fade_duration) -> Signal:
	return _to_color(CLEAR, duration)
	
func fade_to_black(duration: float = fade_duration) -> Signal:
	return _to_color(Color.BLACK, duration)

func _to_color(new_color: Color, duration: float) -> Signal:
	if _tween && _tween.is_running():
		_tween.Kill()
	_tween = create_tween()
	_tween.tween_property(fade, "color", new_color, duration)
	return _tween.finished
 
