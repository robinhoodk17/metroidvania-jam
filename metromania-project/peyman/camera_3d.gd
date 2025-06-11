extends Camera3D

@onready var player : Node3D = get_parent()
@onready var mode : CameraMode = CameraMode.CELESTE 
@onready var target_position : Vector3 = global_position
@onready var last_area_position : Vector3 = target_position
@onready var default_rotation : Vector3 = rotation_degrees
@onready var default_fov : float = fov 
@export var smoothing_frame_count : int = 20  
var celeste_edge_margin :  Vector2 = Vector2(3.0, 1.5) 
var celeste_slow_follow_speed : float = 2.0         
var celeste_fast_move_speed : float = 15.0         
var celeste_area_threshold : float = 5.0           
var hollow_follow_speed : float = 7.0               
enum CameraMode { CELESTE, HOLLOW_KNIGHT }
var recent_y_positions : PackedFloat32Array = PackedFloat32Array()
var shake_active: bool
var slowmo_active: bool
var slowmo_tween: Tween
var tilt_tween: Tween
var zoom_tween: Tween

func _ready() -> void:
	SignalbusPlayer.cam_shake.connect(on_cam_shake)
	SignalbusPlayer.cam_slomo.connect(on_cam_slomo)
	SignalbusPlayer.cam_tilt.connect(on_cam_tilt)
	SignalbusPlayer.cam_fast_zooms.connect(on_cam_fast_zooms)
	SignalbusPlayer.cam_pan.connect(on_cam_pan)

func switch_player(parent: Node3D) -> void:
	reparent(parent)
	player = parent

func _physics_process(delta: float):
	match mode:
		CameraMode.CELESTE:
			_update_celeste_mode(delta)
		CameraMode.HOLLOW_KNIGHT:
			_update_hollow_knight_mode(delta)
	target_position.y = dampen_y()
	global_transform.origin = global_transform.origin.move_toward(target_position, 10 * delta)

func _update_celeste_mode(delta):
	var player_pos : Vector3 = player.global_transform.origin
	var cam_pos : Vector3 = global_transform.origin
	var offset : Vector2 = Vector2(player_pos.x - cam_pos.x, player_pos.y - cam_pos.y)
	var move_camera : Vector3 = Vector3.ZERO
	if abs(offset.x) > celeste_edge_margin.x:
		move_camera.x = sign(offset.x) * celeste_slow_follow_speed * delta
	if abs(offset.y) > celeste_edge_margin.y:
		move_camera.y = sign(offset.y) * celeste_slow_follow_speed * delta
	target_position += move_camera
	if player_pos.distance_to(last_area_position) > celeste_area_threshold:
		target_position.x = lerp(target_position.x, player_pos.x, min(1, celeste_fast_move_speed * delta))
		target_position.y = lerp(target_position.y, player_pos.y, min(1, celeste_fast_move_speed * delta))
		last_area_position = player_pos

func _update_hollow_knight_mode(delta):
	var player_pos = player.global_transform.origin
	target_position.x = lerp(target_position.x, player_pos.x, hollow_follow_speed * delta)
	target_position.y = lerp(target_position.y, player_pos.y, hollow_follow_speed * delta)
 
func dampen_y() -> float:
	recent_y_positions.append(player.global_position.y)
	if recent_y_positions.size() > smoothing_frame_count:
		recent_y_positions.remove_at(0)
	var sum_y : float = 0.0
	for i in recent_y_positions:
		sum_y += i
	var avg_y = sum_y / recent_y_positions.size()
	return avg_y

#region cam_signals
func on_cam_shake(duration: float = 0.3) -> void:
	if shake_active:
		return
	else:
		shake_active = true
		handle_camera_shake(duration)

func on_cam_slomo(duration: float = 0.5) -> void:
	if slowmo_active:
		return 
	else:
		slowmo_active = true
		await handle_cam_slowmo(duration)
		slowmo_active = false
 
func handle_camera_shake(duration : float) -> void:
	var period : float = duration
	var magnitude : float = 0.4
	var initial_transform = self.transform
	var elapsed_time : float = 0.0
	while elapsed_time < period:
		var offset : Vector3 = Vector3(
			randf_range(-magnitude, magnitude),
			randf_range(-magnitude, magnitude),
			0.0
		)
		self.transform.origin = initial_transform.origin + offset
		elapsed_time += get_process_delta_time()
		await get_tree().process_frame
	self.transform = initial_transform
	shake_active = false
 
func handle_cam_slowmo(duration : float) -> Signal:
	if slowmo_tween && slowmo_tween.is_running():
		slowmo_tween.kill()
	slowmo_tween = get_tree().create_tween()
	slowmo_tween.tween_property(Engine, "time_scale", 0.05, 0.5)
	slowmo_tween.tween_property(Engine, "time_scale", 1.0, duration/2)
	return slowmo_tween.finished

func on_cam_tilt(duration : float = 0.15) -> Signal:
	var tilt_degrees : float = 5.0
	var target_rotation = default_rotation
	target_rotation.z += randf_range(-tilt_degrees, tilt_degrees)
	if tilt_tween && tilt_tween.is_running():
		tilt_tween.kill()
	tilt_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tilt_tween.tween_property(self, "rotation_degrees", target_rotation, duration)
	tilt_tween.tween_property(self, "rotation_degrees", default_rotation, duration)
	return tilt_tween.finished

func on_cam_fast_zooms(duration: float = 0.15) -> Signal:
	var zoom_amount : float = 10.0
	var target_fov : float = clamp(default_fov - zoom_amount, 10, default_fov) 
	if zoom_tween && zoom_tween.is_running():
		zoom_tween.kill()
	zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(self, "fov", target_fov, duration)
	zoom_tween.tween_property(self, "fov", default_fov, duration)
	return zoom_tween.finished 

func on_cam_pan(direction: float, amount: float) -> void:
	### use only 1 and -1 for direction, 1 for right and -1 for left 
	var right : Vector3 = global_transform.basis.x.normalized()
	global_translate(right * direction * amount)
 
#endregion 
