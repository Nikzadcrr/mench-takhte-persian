class_name OrbitCamera3D
extends Camera3D

var target := Vector3.ZERO
var distance := 27.0
var yaw := 0.0
var pitch := -1.12

var _target_dist := 27.0
var _target_yaw := 0.0
var _target_pitch := -1.12
var _dragging := false
var _min_dist := 14.0
var _max_dist := 38.0


func configure(p_target: Vector3, p_dist: float, p_pitch_deg: float, p_yaw_deg: float = 0.0, p_fov: float = 44.0) -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	target = p_target
	distance = p_dist
	_target_dist = p_dist
	pitch = deg_to_rad(p_pitch_deg)
	_target_pitch = pitch
	yaw = deg_to_rad(p_yaw_deg)
	_target_yaw = yaw
	fov = p_fov
	_update_transform()


func apply_preset(preset_idx: int, default_dist: float = 27.0) -> void:
	match preset_idx:
		0: # ایزومتریک موبایل (پیش‌فرض)
			_target_dist = default_dist
			_target_pitch = deg_to_rad(-66.0)
			_target_yaw = 0.0
		1: # نمای عمودی از بالا (مناسب لمس دقیق)
			_target_dist = default_dist * 1.04
			_target_pitch = deg_to_rad(-85.0)
			_target_yaw = 0.0
		2: # نمای سینمایی سه‌بعدی
			_target_dist = default_dist * 0.90
			_target_pitch = deg_to_rad(-48.0)
			_target_yaw = deg_to_rad(14.0)


func handle_orbit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_dist = clampf(_target_dist - 1.4, _min_dist, _max_dist)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_dist = clampf(_target_dist + 1.4, _min_dist, _max_dist)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_target_yaw -= mm.relative.x * 0.0065
		_target_pitch = clampf(_target_pitch - mm.relative.y * 0.0055, deg_to_rad(-86.0), deg_to_rad(-34.0))


func _unhandled_input(event: InputEvent) -> void:
	handle_orbit_input(event)


func _process(delta: float) -> void:
	var k := clampf(delta * 8.5, 0.0, 1.0)
	distance = lerpf(distance, _target_dist, k)
	yaw = lerpf(yaw, _target_yaw, k)
	pitch = lerpf(pitch, _target_pitch, k)
	_update_transform()


func _update_transform() -> void:
	var dir := Vector3(
		sin(yaw) * cos(pitch),
		-sin(pitch),
		cos(yaw) * cos(pitch)
	)
	var eye := target + dir * distance
	if is_inside_tree():
		look_at_from_position(eye, target, Vector3.UP)
	else:
		position = eye
