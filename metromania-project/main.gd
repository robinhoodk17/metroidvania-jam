extends Node
 
const CLEAR := Color(0,0,0,0)
var _tween: Tween
var fade : ColorRect
@export var fade_duration := 1.0
@export var musics : Array[AudioStream]
@onready var canvas_layer: CanvasLayer = $CanvasLayer
const HEALTH_BAR_FILL = preload("res://peyman/Health bar fill.png")
const HEALTH_BAR_OUTLINE = preload("res://peyman/Health bar outline.png")
var progress_bar: TextureProgressBar

func _ready() -> void:
	Ui.show_ui("MainMenu")
	create_fade()
	create_progress_bar()
	if SaveLoad.progress == null:
		SaveLoad.progress = Progress.new()
		print("progress resource created")
	if musics.size() > 0:
		Music.play_music(musics[0])
	await fade_to_clear()
	set_progress_bar_value(50)
 
func set_progress_bar_value(amount: float) -> void:
	var max_value = progress_bar.max_value
	var clamped_amount = clamp(amount, 0, max_value)
	var tween: Tween
	if tween && tween.is_running():
		tween.Kill()
	tween = create_tween()
	tween.tween_property(progress_bar, "value", clamped_amount, 0.3)
	
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
 
