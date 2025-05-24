extends ColorRect

@export var _duration := 1.0
const CLEAR : Color = Color(0,0,0,0)
var _tween: Tween
func _ready() -> void:
	#visibile = true
	pass

func to_clear(duration: float = _duration) -> Signal:
	return _to_color(CLEAR, duration)
	
func to_black(duration: float = _duration) -> Signal:
	return _to_color(Color.BLACK, duration)

func _to_color(new_color: Color, duration: float) -> Signal:
	if _tween && _tween.is_running():
		_tween.Kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", new_color, duration)
	return _tween.finished

