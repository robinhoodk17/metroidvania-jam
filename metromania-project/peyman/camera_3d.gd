extends Camera3D

@onready var player : Node3D = get_parent()
@onready var mode : CameraMode = CameraMode.CELESTE 
@onready var target_position : Vector3 = global_position
@onready var last_area_position : Vector3 = target_position
var celeste_edge_margin := Vector2(3.0, 1.5) 
var celeste_slow_follow_speed := 2.0         
var celeste_fast_move_speed := 15.0         
var celeste_area_threshold := 5.0           
var hollow_follow_speed := 7.0               
enum CameraMode { CELESTE, HOLLOW_KNIGHT }
var shake_active: bool
var slowmo_active: bool
var title_active: bool
var zoom_active: bool
var base_y : float = 0.0  
var vertical_limit : float = 0.5 
var smoothing_speed : float = 5.0 
@onready var default_rotation : Vector3 = rotation_degrees
@onready var default_fov : float = 90
 
func _ready() -> void:
	add_to_group("camera")
	SignalbusPlayer.cam_shake.connect(on_cam_shake)
	SignalbusPlayer.cam_slomo.connect(on_cam_slomo)
	SignalbusPlayer.cam_tilt.connect(on_cam_tilt)
	SignalbusPlayer.cam_zoom_in_out.connect(on_cam_zoom_in_out)
	
func switch_player(parent: Node3D) -> void:
	reparent(parent)
	player = parent

func _process(delta):
	match mode:
		CameraMode.CELESTE:
			_update_celeste_mode(delta)
		CameraMode.HOLLOW_KNIGHT:
			_update_hollow_knight_mode(delta)
	var pos : Vector3 = global_position.move_toward(target_position, 10 * delta)
	var target_y = clamp(pos.y, base_y - vertical_limit, base_y + vertical_limit)
	pos.y = lerp(pos.y, target_y, smoothing_speed * delta)
	global_position = pos

func _update_celeste_mode(delta):
	var player_pos : Vector3 = player.global_position
	var cam_pos : Vector3 = global_position
	var offset : Vector2 = Vector2(player_pos.x - cam_pos.x, player_pos.y - cam_pos.y)
	var move_camera : Vector3 = Vector3.ZERO
	if abs(offset.x) > celeste_edge_margin.x:
		var direction_x = sign(offset.x)
		move_camera.x = direction_x * celeste_slow_follow_speed * delta
	if abs(offset.y) > celeste_edge_margin.y:
		var direction_y = sign(offset.y)
		move_camera.y = direction_y * celeste_slow_follow_speed * delta
	target_position += move_camera
	if player_pos.distance_to(last_area_position) > celeste_area_threshold:
		target_position.x = lerp(target_position.x, player_pos.x, min(1, celeste_fast_move_speed * delta))
		target_position.y = lerp(target_position.y, player_pos.y, min(1, celeste_fast_move_speed * delta))
		last_area_position = player_pos
 
func _update_hollow_knight_mode(delta):
	var player_pos : Vector3 = player.global_position
	target_position.x = lerp(target_position.x, player_pos.x, hollow_follow_speed * delta)
	target_position.y = lerp(target_position.y, player_pos.y, hollow_follow_speed * delta)
 
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
 
func on_cam_tilt(duration: float = 0.15) -> void:
	if title_active:
		return
	else:
		title_active = true
		await handle_camera_tilt(duration)
		title_active = false
		
func on_cam_zoom_in_out(duration: float = 0.15) -> void:
	if zoom_active:
		return
	else:
		zoom_active = true
		await handle_camera_zoom(duration)
		zoom_active = false 

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
	var _tween: Tween = get_tree().create_tween()
	_tween.tween_property(Engine, "time_scale", 0.05, 0.5)
	_tween.tween_property(Engine, "time_scale", 1.0, duration/2)
	return _tween.finished

func handle_camera_tilt(duration : float) -> Signal:
	var tilt_degrees : float = 5.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target_rotation = default_rotation
	target_rotation.z += randf_range(-tilt_degrees, tilt_degrees)
	tween.tween_property(self, "rotation_degrees", target_rotation, duration)
	tween.tween_property(self, "rotation_degrees", default_rotation, duration)
	return tween.finished

func handle_camera_zoom(duration: float) -> Signal:
	var zoom_amount : float = 10.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target_fov : float = clamp(default_fov - zoom_amount, 10, default_fov) 
	tween.tween_property(self, "fov", target_fov, duration)
	tween.tween_property(self, "fov", default_fov, duration)
	return tween.finished 
