extends Camera3D

var default_rotation : Vector3 = rotation_degrees
var shake_active: bool
var slowmo_active: bool
var slowmo_tween: Tween
var tilt_tween: Tween
var zoom_tween: Tween

@onready var default_fov : float = fov 
@onready var player : Node3D = get_parent()
@onready var second_timer = create_timer(7.0)
@onready var small_area: Area3D = create_area_with_collision(Vector3(3, 3, 3,)) 
@onready var big_area: Area3D = create_area_with_collision(Vector3(8, 8, 8,))
@onready var camera_static_position: Vector3 = global_transform.origin 
@export var camera_mode := "Celeste" 
@export var static_control : float = 8.0

var in_small_area : bool = true:
	set(value):
		camera_static_position = _desired_pos
		in_small_area = value
var in_big_area : bool = true 
var lerp_speed_slow := 0.5 
var lerp_speed_fast := 2.5 
var y_dampening_factor := 0.1 
var vertical_offset = Vector3(0, 1, 0)  
var side_offset = Vector3(0, 0, 10)
var _desired_pos : Vector3

func create_timer(wait_time: float = 1.0, one_shot: bool = true) -> Timer:
	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	add_child(timer)
	return timer
	
func create_area_with_collision(size: Vector3) -> Area3D:
	var area : Area3D = Area3D.new()
	var collision_shape : CollisionShape3D = CollisionShape3D.new()
	var box_shape : BoxShape3D = BoxShape3D.new()
	box_shape.extents = size / 2
	collision_shape.shape = box_shape
	area.add_child(collision_shape)
	area.collision_layer = 0
	area.collision_mask = 1 << 2
	area.monitorable = false
	add_child(area)
	return area
 
func _ready() -> void:
	position = vertical_offset + side_offset
	big_area.global_transform.origin =  player.global_transform.origin
	small_area.global_transform.origin = player.global_transform.origin
	second_timer.start()
	second_timer.timeout.connect(on_second_timer_timeout)
	small_area.body_entered.connect(func(body: Node3D): if body == player && in_small_area == false: in_small_area = true)
	small_area.body_exited.connect(func(body: Node3D): if body == player && in_small_area == true: in_small_area = false)
	big_area.body_entered.connect(func(body: Node3D): if body == player && in_big_area == false: in_big_area = true)
	big_area.body_exited.connect(func(body: Node3D): if body == player && in_big_area == true: in_big_area = false)
	SignalbusPlayer.cam_shake.connect(on_cam_shake)
	SignalbusPlayer.cam_slomo.connect(on_cam_slomo)
	SignalbusPlayer.cam_tilt.connect(on_cam_tilt)
	SignalbusPlayer.cam_fast_zooms.connect(on_cam_fast_zooms)
	SignalbusPlayer.cam_pan.connect(on_cam_pan)
 
func _physics_process(delta):
	var player_pos : Vector3 = player.global_transform.origin
	var desired_pos : Vector3 = player_pos + vertical_offset + side_offset
	var target_pos : Vector3 = global_transform.origin
	_desired_pos = desired_pos
	match camera_mode:
		"Celeste":
			if in_small_area:
				target_pos = target_pos.lerp(camera_static_position, lerp_speed_slow * delta)
			elif in_big_area and not in_small_area:
				target_pos.x = lerp(global_transform.origin.x, desired_pos.x, lerp_speed_slow * delta)
				target_pos.z = lerp(global_transform.origin.z, desired_pos.z, lerp_speed_slow * delta)
				target_pos.y = lerp(global_transform.origin.y, desired_pos.y, y_dampening_factor * delta)
				if target_pos.distance_to(desired_pos) < 0.01:
					target_pos = desired_pos
			else:
				target_pos.x = lerp(global_transform.origin.x, desired_pos.x, lerp_speed_fast * delta)
				target_pos.z = lerp(global_transform.origin.z, desired_pos.z, lerp_speed_fast * delta)
				target_pos.y = lerp(global_transform.origin.y, desired_pos.y, y_dampening_factor * delta)
				if target_pos.distance_to(desired_pos) < 0.01:
					target_pos = desired_pos
 
		"HollowKnight":
			if in_big_area:
				target_pos = target_pos.lerp(camera_static_position, lerp_speed_slow * delta)
			else:
				target_pos.x = lerp(global_transform.origin.x, desired_pos.x, lerp_speed_slow * delta)
				target_pos.z = lerp(global_transform.origin.z, desired_pos.z, lerp_speed_slow * delta)
				target_pos.y = lerp(global_transform.origin.y, desired_pos.y, y_dampening_factor * delta)
				if target_pos.distance_to(desired_pos) < 0.01:
					target_pos = desired_pos
				if in_small_area:
					camera_static_position = target_pos

	global_transform.origin = target_pos
 
func switch_player(parent: Node3D) -> void:
	reparent(parent)
	player = parent
  
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
 
func on_second_timer_timeout () -> void:
	small_area.monitoring = false
	big_area.monitoring = false
	await get_tree().create_timer(0.1).timeout
	small_area.monitoring = true
	big_area.monitoring = true
	second_timer.start()
