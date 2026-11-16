extends GutTest
## P1-04 AC: switching camera mid-move causes no input glitch. HOLLOW keeps
## moving, the move direction turns smoothly (blended), and aim stays valid.

const HOLLOW_SCENE: String = "res://actors/player/hollow.tscn"
const RIG_SCENE: String = "res://actors/player/camera/camera_rig.tscn"
## A texture HOLLOW uses. CI checks out without LFS, so it may be a pointer file.
const LFS_PROBE: String = "res://assets/textures/pbr/metal_plate/metal_plate_diff_1k.jpg"

var _world: Node3D
var _hollow: Hollow
var _rig: CameraRig


func before_each() -> void:
	Settings.set_camera_mode(Settings.CameraMode.TACTICAL)


func after_each() -> void:
	Input.action_release(&"move_up")
	Settings.set_camera_mode(Settings.CameraMode.TACTICAL)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_world):
		_world.free()


func test_switch_mid_move_keeps_moving_smoothly() -> void:
	if _lfs_missing():
		pending("Needs LFS art (CI runs without LFS)")
		return
	_build_world()
	await wait_physics_frames(5)
	Input.action_press(&"move_up")
	await wait_physics_frames(30)
	var before: Vector3 = _flat(_hollow.velocity)
	assert_gt(before.length(), 3.0, "moving in Tactical")
	assert_lt(before.normalized().x, -0.9, "forward = -X with tactical yaw 90°")

	Settings.set_camera_mode(Settings.CameraMode.SHOULDER)
	var prev: Vector3 = before
	var max_turn: float = 0.0
	for i in 30:
		await wait_physics_frames(1)
		var v: Vector3 = _flat(_hollow.velocity)
		assert_gt(v.length(), 1.0, "never stops during the switch")
		max_turn = maxf(max_turn, prev.angle_to(v))
		prev = v
	assert_lt(max_turn, deg_to_rad(25.0), "direction changes gradually, no snap")
	assert_ne(InputRouter.get_aim_target(), Vector3.ZERO, "aim still served")


func _build_world() -> void:
	_world = Node3D.new()
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	_hollow = (load(HOLLOW_SCENE) as PackedScene).instantiate() as Hollow
	_world.add_child(_hollow)
	_rig = (load(RIG_SCENE) as PackedScene).instantiate() as CameraRig
	_rig.target = _hollow
	_rig.tactical_yaw_deg = 90.0
	_world.add_child(_rig)
	add_child(_world)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _lfs_missing() -> bool:
	var f: FileAccess = FileAccess.open(LFS_PROBE, FileAccess.READ)
	if f == null:
		return true
	return f.get_buffer(7).get_string_from_ascii() == "version"
