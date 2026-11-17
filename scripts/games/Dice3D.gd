class_name Dice3D
extends Node3D

var _mesh_pivot: Node3D
var _value: int = 1
var _base_pos: Vector3 = Vector3.ZERO
var _is_rolling := false

const FACE_EULERS := {
	1: Vector3(0.0, 0.0, 0.0),
	2: Vector3(-PI * 0.5, 0.0, 0.0),
	3: Vector3(0.0, 0.0, PI * 0.5),
	4: Vector3(0.0, 0.0, -PI * 0.5),
	5: Vector3(PI * 0.5, 0.0, 0.0),
	6: Vector3(PI, 0.0, 0.0),
}


func _ready() -> void:
	_mesh_pivot = Node3D.new()
	add_child(_mesh_pivot)

	var scene: PackedScene = load("res://assets/models/dice.glb")
	if scene:
		var inst := scene.instantiate()
		_mesh_pivot.add_child(inst)
	_base_pos = position
	set_face_immediate(1)


func set_rest_position(pos: Vector3) -> void:
	_base_pos = pos
	position = pos


func set_face_immediate(val: int) -> void:
	_value = clampi(val, 1, 6)
	var face_basis := Basis.from_euler(FACE_EULERS[_value])
	var yaw := Basis(Vector3.UP, randf_range(-0.35, 0.35))
	_mesh_pivot.transform.basis = yaw * face_basis


func roll_to(target_val: int, duration: float = 0.62) -> void:
	_value = clampi(target_val, 1, 6)
	_is_rolling = true

	var start_pos := _base_pos
	var land_pos := _base_pos + Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	var final_basis := Basis(Vector3.UP, randf_range(-0.45, 0.45)) * Basis.from_euler(FACE_EULERS[_value])
	var final_quat := final_basis.get_rotation_quaternion()

	var spin_axis := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.0), randf_range(-1.0, 1.0)).normalized()
	if spin_axis.length() < 0.1:
		spin_axis = Vector3(1, 1, 0).normalized()

	var tw := create_tween()
	tw.tween_method(func(t: float):
		# Parabolic bounce + second small hop
		var h := 0.0
		if t < 0.72:
			var u := t / 0.72
			h = sin(u * PI) * 2.2
		else:
			var u2 := (t - 0.72) / 0.28
			h = sin(u2 * PI) * 0.45
		position = start_pos.lerp(land_pos, t) + Vector3(0.0, h, 0.0)

		if t < 0.80:
			var spin_q := Quaternion(spin_axis, t * TAU * 3.0)
			_mesh_pivot.quaternion = spin_q * final_quat
		else:
			var settle := (t - 0.80) / 0.20
			_mesh_pivot.quaternion = _mesh_pivot.quaternion.slerp(final_quat, settle)
	, 0.0, 1.0, duration)

	await tw.finished
	_mesh_pivot.quaternion = final_quat
	position = land_pos
	_is_rolling = false
