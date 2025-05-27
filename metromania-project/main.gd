extends Node
 
const CLEAR := Color(0,0,0,0)
var _tween: Tween
var canvas_layer : CanvasLayer
var fade : ColorRect
@export var fade_duration := 1.0
@export var musics : Array[AudioStream]

func _ready() -> void:
	create_and_add_canvas_layer()
	create_fade()
	if musics.size() > 0:
		Music.play_music(musics[0])
	await fade_to_clear()
 
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
func create_and_add_canvas_layer() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	add_child(canvas_layer)
 
func create_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color.BLACK 
	fade.anchor_left = 0
	fade.anchor_top = 0
	fade.anchor_right = 1
	fade.anchor_bottom = 1
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade)
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
 
