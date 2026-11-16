extends GutTest
## P1-01…04 pure math: camera-relative movement, stick aim, camera placement,
## the shoulder aim-ray start, and HOLLOW's acceleration and turning.


func test_move_to_world_zero_yaw_maps_forward_to_minus_z() -> void:
	var v: Vector3 = InputRouter.move_to_world(Vector2(0.0, -1.0), 0.0)
	assert_almost_eq(v, Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)


func test_move_to_world_follows_camera_yaw() -> void:
	# Camera yawed 90°: it sits on +X looking toward -X, so forward is -X.
	var forward: Vector3 = InputRouter.move_to_world(Vector2(0.0, -1.0), PI / 2.0)
	assert_almost_eq(forward, Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.001)
	var left: Vector3 = InputRouter.move_to_world(Vector2(-1.0, 0.0), PI / 2.0)
	assert_almost_eq(left, Vector3(0.0, 0.0, 1.0), Vector3.ONE * 0.001)


func test_stick_aim_point_is_at_distance_and_height() -> void:
	var p: Vector3 = TacticalCameraMode.stick_aim_point(
		Vector3(1.0, 0.0, 1.0), Vector2(1.0, 0.0), 0.0, 8.0, 1.2
	)
	assert_almost_eq(p, Vector3(9.0, 1.2, 1.0), Vector3.ONE * 0.001)


func test_tactical_transform_pitch_and_distance() -> void:
	var focus: Vector3 = Vector3(2.0, 0.0, -3.0)
	var xf: Transform3D = TacticalCameraMode.compute_transform(focus, 55.0, 14.0, 0.0)
	assert_almost_eq(xf.origin.distance_to(focus), 14.0, 0.001)
	var look: Vector3 = -xf.basis.z
	assert_almost_eq(rad_to_deg(asin(-look.y)), 55.0, 0.01, "looks down at the pitch angle")
	assert_almost_eq((focus - xf.origin).normalized(), look, Vector3.ONE * 0.001)


func test_aim_ray_starts_level_with_player() -> void:
	var start: Vector3 = ShoulderCameraMode.aim_ray_start(
		Vector3(0.0, 2.0, 4.0), Vector3(0.0, 0.0, -1.0), Vector3(0.5, 1.6, 0.0)
	)
	assert_almost_eq(start, Vector3(0.0, 2.0, 0.0), Vector3.ONE * 0.001)


func test_aim_ray_never_starts_behind_camera() -> void:
	var start: Vector3 = ShoulderCameraMode.aim_ray_start(
		Vector3.ZERO, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 5.0)
	)
	assert_eq(start, Vector3.ZERO)


func test_velocity_accelerates_then_caps() -> void:
	var wish: Vector3 = Vector3(6.0, 0.0, 0.0)
	var v: Vector3 = Hollow.step_velocity(Vector3.ZERO, wish, 40.0, 30.0, 0.1)
	assert_almost_eq(v.x, 4.0, 0.001, "40 m/s² for 0.1 s")
	v = Hollow.step_velocity(v, wish, 40.0, 30.0, 0.1)
	assert_almost_eq(v.x, 6.0, 0.001, "never exceeds the wish speed")


func test_velocity_brakes_with_friction_when_no_input() -> void:
	var v: Vector3 = Hollow.step_velocity(Vector3(6.0, 0.0, 0.0), Vector3.ZERO, 40.0, 30.0, 0.1)
	assert_almost_eq(v.x, 3.0, 0.001)


func test_rotate_angle_toward_takes_shortest_way_and_caps_step() -> void:
	var a: float = Hollow.rotate_angle_toward(deg_to_rad(170.0), deg_to_rad(-170.0), 0.1)
	assert_gt(a, deg_to_rad(170.0), "crosses ±180° instead of turning 340° the long way")
	var b: float = Hollow.rotate_angle_toward(0.0, 0.05, 0.1)
	assert_almost_eq(b, 0.05, 0.0001, "snaps when within one step")
