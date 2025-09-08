extends Node
 
const CLEAR : Color = Color(0,0,0,0)
var fade_tween: Tween
var progress_tween: Tween
@export var fade_duration := 1.0
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var fade : ColorRect = create_fade()
@onready var progress_bar: TextureProgressBar = create_progress_bar()
const HEALTH_BAR_FILL = preload("res://peyman/Health bar fill.png")
const HEALTH_BAR_OUTLINE = preload("res://peyman/Health bar outline.png")

func _ready() -> void:
	call_deferred("late_ready")
	if SaveLoad.progress == null:
		SaveLoad.progress = Progress.new()
		print("progress resource created")
	Music.play_music("[Idea 2] Into the Darkness")
	progress_bar.hide()
	SignalbusPlayer.cam_pan.emit(1, 20)
	await fade_to_clear()
	set_progress_bar_value(50)
 
func late_ready() -> void:
	Ui.show_ui("MainMenu")
	await get_tree().create_timer(5).timeout

func play_different_music (int):
	pass

func set_progress_bar_value(amount: float) -> void:
	var max_value = progress_bar.max_value
	var clamped_amount = clamp(amount, 0, max_value)
	if progress_tween && progress_tween.is_running():
		progress_tween.Kill()
	progress_tween = create_tween()
	progress_tween.tween_property(progress_bar, "value", clamped_amount, 0.3)
	
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
 
func create_fade() -> ColorRect:
	var fade : ColorRect = ColorRect.new()
	fade.name = "fade"
	fade.color = Color.BLACK 
	fade.anchor_left = 0
	fade.anchor_top = 0
	fade.anchor_right = 1
	fade.anchor_bottom = 1
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade)
	return fade 

func create_progress_bar() -> TextureProgressBar:
	var progress_bar : TextureProgressBar = TextureProgressBar.new()
	progress_bar.name = "XPProgressBar"
	progress_bar.scale *= 0.4
	progress_bar.texture_over = HEALTH_BAR_OUTLINE
	progress_bar.texture_progress = HEALTH_BAR_FILL
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.set_position(Vector2(25.0, 25.0)) 
	canvas_layer.add_child(progress_bar)
	return progress_bar
 
func fade_to_clear(duration: float = fade_duration) -> Signal:
	return _to_color(CLEAR, duration)
	
func fade_to_black(duration: float = fade_duration) -> Signal:
	return _to_color(Color.BLACK, duration)

func _to_color(new_color: Color, duration: float) -> Signal:
	if fade_tween && fade_tween.is_running():
		fade_tween.Kill()
	fade_tween = create_tween()
	fade_tween.tween_property(fade, "color", new_color, duration)
	return fade_tween.finished
 
