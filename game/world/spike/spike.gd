extends Node3D
## Phase 0.5 web 3D feasibility spike: ruined street + player + 40 chasing droids.
##
## Covers P05-01 (street), P05-03 (droids, tracers, impacts) and P05-04 (both
## cameras). F3 shows the performance overlay used for the P05-06 measurements.
## TEST CODE: values are inline on purpose. Production systems follow the
## data-driven rules from Phase 1.

const DROID_COUNT: int = 40
const AI_HZ: float = 15.0
const PLAYER_SPEED: float = 6.0
const GRAVITY: float = 20.0
const FIRE_INTERVAL: float = 0.12
const FIRE_RANGE: float = 60.0
const TRACER_POOL: int = 24
const TRACER_LIFE: float = 0.06
const IMPACT_POOL: int = 12
const RESPAWN_DELAY: float = 1.5
const TACTICAL_PITCH_DEG: float = 55.0
const TACTICAL_DISTANCE: float = 14.0
## Tactical camera looks along the street (+X → -X) so facades never block it.
const TACTICAL_YAW_DEG: float = 90.0
const STATS_WARMUP: float = 3.0
const TACTICAL_LOOK_AHEAD: float = 3.0
const SHOULDER_PIVOT: Vector3 = Vector3(0.0, 1.6, 0.0)
const SHOULDER_OFFSET: Vector3 = Vector3(0.8, 0.4, 3.4)
const MOUSE_SENSITIVITY: float = 0.0025
const STICK_LOOK_SPEED: float = 2.5
const CAMERA_SMOOTHING: float = 8.0
const FRAME_WINDOW: int = 600
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMIES: int = 8
const HINT_TEXT: String = "WASD move · Mouse aim · LMB fire · V camera · F3 stats · F4 quality"

var _player: CharacterBody3D
var _player_visual: Node3D
var _droids: Array[SpikeDroid] = []
var _spawns: Array[Vector3] = []
var _respawns: Array[Array] = []
var _ai_accum: float = 0.0
var _fire_cooldown: float = 0.0
var _yaw: float = 0.0
var _pitch: float = -0.15
var _aim_point: Vector3 = Vector3.ZERO
var _kills: int = 0
var _tracers: MultiMesh
var _tracer_life: PackedFloat32Array = PackedFloat32Array()
var _tracer_next: int = 0
var _impacts: Array[CPUParticles3D] = []
var _impact_next: int = 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _frame_index: int = 0
var _stats_timer: float = 0.0
var _avg_fps: float = 0.0
var _low_fps: float = 0.0
var _warmup: float = STATS_WARMUP
var _log_timer: float = 10.0

@onready var _sector: Node3D = $StreetSector
@onready var _camera: Camera3D = $Camera3D
@onready var _overlay: Label = $HUD/Overlay
@onready var _crosshair: Label = $HUD/Crosshair
@onready var _hint: Label = $HUD/Hint


func _ready() -> void:
	for marker: Node in _sector.get_node("Markers").get_children():
		if marker.name.begins_with("DroidSpawn"):
			_spawns.append((marker as Node3D).global_position)
	_frame_ms.resize(FRAME_WINDOW)
	_build_player((_sector.get_node("Markers/PlayerStart") as Node3D).global_position)
	_build_droids()
	_build_tracers()
	_build_impacts()
	_hint.text = HINT_TEXT
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	EventBus.camera_mode_changed.connect(_on_camera_mode_changed)
	EventBus.quality_preset_changed.connect(_on_quality_changed)
	_on_quality_changed(QualityManager.preset)
	_on_camera_mode_changed(Settings.camera_mode)
	_update_camera(1.0)
	if OS.get_cmdline_user_args().has("--spike-shot"):
		_auto_screenshots()


func _unhandled_input(event: InputEvent) -> void:
	var shoulder: bool = Settings.camera_mode == Settings.CameraMode.SHOULDER
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and shoulder and captured:
		var motion: Vector2 = (event as InputEventMouseMotion).relative
		_yaw -= motion.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.y * MOUSE_SENSITIVITY, -0.6, 0.35)
	elif event is InputEventMouseButton and event.is_pressed() and shoulder and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"switch_camera"):
		Settings.toggle_camera_mode()
	elif _is_key_press(event, KEY_F4):
		QualityManager.cycle_preset()
		_stats_timer = 0.0
	elif event.is_action_pressed(&"toggle_debug"):
		_overlay.visible = not _overlay.visible
	elif event.is_action_pressed(&"pause"):
		if captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif not OS.has_feature("web"):
			get_tree().quit()


func _physics_process(delta: float) -> void:
	var move: Vector2 = InputRouter.get_move_vector()
	var dir: Vector3 = Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, _camera_yaw())
	_player.velocity.x = dir.x * PLAYER_SPEED
	_player.velocity.z = dir.z * PLAYER_SPEED
	if _player.is_on_floor():
		_player.velocity.y = 0.0
	else:
		_player.velocity.y -= GRAVITY * delta
	_player.move_and_slide()

	_ai_accum += delta
	if _ai_accum >= 1.0 / AI_HZ:
		_ai_accum = 0.0
		var target: Vector3 = _player.global_position
		for droid: SpikeDroid in _droids:
			if droid.alive:
				droid.think(target, _droids)


func _process(delta: float) -> void:
	_record_frame(delta)
	if Settings.camera_mode == Settings.CameraMode.SHOULDER:
		var stick: Vector2 = InputRouter.get_stick_aim_vector()
		_yaw -= stick.x * STICK_LOOK_SPEED * delta
		_pitch = clampf(_pitch - stick.y * STICK_LOOK_SPEED * delta, -0.6, 0.35)
	_update_camera(minf(1.0, delta * CAMERA_SMOOTHING))
	_update_aim()
	var facing: Vector3 = _aim_point - _player.global_position
	if Vector2(facing.x, facing.z).length() > 0.3:
		_player_visual.rotation.y = atan2(-facing.x, -facing.z)

	_fire_cooldown -= delta
	if Input.is_action_pressed(&"fire_primary") and _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_INTERVAL
		_fire()
	_update_tracers(delta)
	_update_respawns(delta)
	_log_stats(delta)
	_stats_timer -= delta
	if _overlay.visible and _stats_timer <= 0.0:
		_stats_timer = 0.5
		_update_overlay()


func _update_camera(weight: float) -> void:
	var target: Vector3 = _player.global_position
	if Settings.camera_mode == Settings.CameraMode.TACTICAL:
		var ahead: Vector3 = (_aim_point - target) * 0.25
		ahead.y = 0.0
		var focus: Vector3 = target + ahead.limit_length(TACTICAL_LOOK_AHEAD)
		var pitch: float = deg_to_rad(TACTICAL_PITCH_DEG)
		var offset: Vector3 = Vector3(0.0, sin(pitch), cos(pitch)) * TACTICAL_DISTANCE
		var eye: Vector3 = focus + offset.rotated(Vector3.UP, _camera_yaw())
		var desired: Transform3D = Transform3D(Basis(), eye).looking_at(
			focus + Vector3.UP, Vector3.UP
		)
		_camera.global_transform = _camera.global_transform.interpolate_with(desired, weight)
		return
	var pivot: Vector3 = target + SHOULDER_PIVOT
	var look: Basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	var eye_pos: Vector3 = pivot + look * SHOULDER_OFFSET
	var hit: Dictionary = _raycast(pivot, eye_pos, LAYER_WORLD)
	if not hit.is_empty():
		eye_pos = (hit["position"] as Vector3) + (pivot - eye_pos).normalized() * 0.2
	_camera.global_transform = Transform3D(look, eye_pos)


func _update_aim() -> void:
	var mask: int = LAYER_WORLD | LAYER_ENEMIES
	if Settings.camera_mode == Settings.CameraMode.SHOULDER:
		var from: Vector3 = _camera.global_position
		var to: Vector3 = from - _camera.global_basis.z * FIRE_RANGE
		var hit: Dictionary = _raycast(from, to, mask)
		_aim_point = to if hit.is_empty() else hit["position"]
		return
	var stick: Vector2 = InputRouter.get_stick_aim_vector()
	if InputRouter.active_device == InputRouter.Device.GAMEPAD and stick.length() > 0.2:
		var stick_dir: Vector3 = Vector3(stick.x, 0.0, stick.y).normalized()
		_aim_point = _player.global_position + stick_dir.rotated(Vector3.UP, _camera_yaw()) * 8.0
		_aim_point.y += 1.2
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = _camera.project_ray_origin(mouse)
	var normal: Vector3 = _camera.project_ray_normal(mouse)
	var hit: Dictionary = _raycast(origin, origin + normal * 200.0, mask)
	if not hit.is_empty():
		_aim_point = hit["position"]
		return
	var plane: Plane = Plane(Vector3.UP, _player.global_position.y + 1.2)
	var on_plane: Variant = plane.intersects_ray(origin, normal)
	if on_plane != null:
		_aim_point = on_plane


func _fire() -> void:
	var facing: Vector3 = -_player_visual.global_basis.z
	var muzzle: Vector3 = _player.global_position + Vector3(0.0, 1.25, 0.0) + facing * 0.7
	var dir: Vector3 = (_aim_point - muzzle).normalized()
	var end: Vector3 = muzzle + dir * FIRE_RANGE
	var hit: Dictionary = _raycast(muzzle, end, LAYER_WORLD | LAYER_ENEMIES)
	if not hit.is_empty():
		end = hit["position"]
		_spawn_impact(end, hit["normal"])
		var droid: SpikeDroid = hit["collider"] as SpikeDroid
		if droid != null and droid.take_hit(1):
			_kills += 1
			_respawns.append([RESPAWN_DELAY, droid])
	_spawn_tracer(muzzle, end)


func _raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask)
	query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 0.1:
		return
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	var basis: Basis = Basis.looking_at(to - from, up).scaled(Vector3(1.0, 1.0, length))
	_tracers.set_instance_transform(_tracer_next, Transform3D(basis, (from + to) * 0.5))
	_tracer_life[_tracer_next] = TRACER_LIFE
	_tracer_next = (_tracer_next + 1) % TRACER_POOL


func _update_tracers(delta: float) -> void:
	for i in TRACER_POOL:
		if _tracer_life[i] <= 0.0:
			continue
		_tracer_life[i] -= delta
		if _tracer_life[i] <= 0.0:
			_tracers.set_instance_transform(
				i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
			)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var sparks: CPUParticles3D = _impacts[_impact_next]
	_impact_next = (_impact_next + 1) % IMPACT_POOL
	sparks.global_position = pos + normal * 0.05
	sparks.direction = normal
	sparks.restart()


func _update_respawns(delta: float) -> void:
	for entry: Array in _respawns:
		entry[0] -= delta
	while not _respawns.is_empty() and _respawns[0][0] <= 0.0:
		var droid: SpikeDroid = _respawns.pop_front()[1]
		var spawn: Vector3 = _spawns[randi() % _spawns.size()]
		droid.respawn(spawn + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5)))


func _on_camera_mode_changed(mode: Settings.CameraMode) -> void:
	var shoulder: bool = mode == Settings.CameraMode.SHOULDER
	_crosshair.visible = shoulder
	if shoulder:
		_yaw = _player_visual.rotation.y
		_pitch = -0.15
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _camera_yaw() -> float:
	if Settings.camera_mode == Settings.CameraMode.SHOULDER:
		return _yaw
	return deg_to_rad(TACTICAL_YAW_DEG)


func _is_key_press(event: InputEvent, key: Key) -> bool:
	var key_event: InputEventKey = event as InputEventKey
	return (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == key
	)


## Applies the per-scene parts of a quality preset (sun shadow range, particles).
func _on_quality_changed(_preset: int) -> void:
	var q: QualityPreset = QualityManager.settings
	var sun: DirectionalLight3D = _sector.get_node("Sun")
	sun.directional_shadow_max_distance = q.shadow_max_distance
	var env: Environment = (_sector.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.glow_enabled = q.glow_enabled
	for sparks: CPUParticles3D in _impacts:
		sparks.amount = maxi(3, int(12 * q.particle_density))


## Debug web builds print the stats to the browser console every 10 s (P05-06 measuring).
func _log_stats(delta: float) -> void:
	if not (OS.has_feature("web") and OS.is_debug_build()):
		return
	_log_timer -= delta
	if _log_timer > 0.0:
		return
	_log_timer = 10.0
	_update_overlay()
	print("[SPIKE] ", _overlay.text.replace("\n", " | "))


func _record_frame(delta: float) -> void:
	if _warmup > 0.0:
		_warmup -= delta
		return
	_frame_ms[_frame_index % FRAME_WINDOW] = delta * 1000.0
	_frame_index += 1


func _update_overlay() -> void:
	var count: int = mini(_frame_index, FRAME_WINDOW)
	if count > 10:
		var window: PackedFloat32Array = _frame_ms.slice(0, count)
		window.sort()
		var total: float = 0.0
		for ms: float in window:
			total += ms
		_avg_fps = 1000.0 / (total / count)
		_low_fps = 1000.0 / window[int(count * 0.99) - 1]
	var alive: int = 0
	for droid: SpikeDroid in _droids:
		alive += 1 if droid.alive else 0
	var rs: Callable = RenderingServer.get_rendering_info
	var lines: PackedStringArray = [
		(
			"FPS %d (avg %.0f · 1%% low %.0f, last %d frames)  ·  %.1f ms"
			% [
				Engine.get_frames_per_second(),
				_avg_fps,
				_low_fps,
				count,
				1000.0 / maxf(_avg_fps, 1.0)
			]
		),
		(
			"Draw calls %d · Primitives %dk · Objects %d"
			% [
				rs.call(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.call(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
				rs.call(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			]
		),
		(
			"Droids %d/%d · Kills %d · Camera %s · Preset %s · Render scale %.2f"
			% [
				alive,
				DROID_COUNT,
				_kills,
				Settings.CameraMode.keys()[Settings.camera_mode],
				QualityManager.get_preset_name(),
				get_viewport().scaling_3d_scale,
			]
		),
		(
			"VRAM %d MB · RAM %d MB · %s · %s"
			% [
				rs.call(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576,
				OS.get_static_memory_usage() / 1048576,
				QualityManager.get_gpu_name(),
				OS.get_name(),
			]
		),
	]
	_overlay.text = "\n".join(lines)


func _build_player(start: Vector3) -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.collision_layer = LAYER_PLAYER
	_player.collision_mask = LAYER_WORLD | LAYER_ENEMIES
	_player.floor_snap_length = 0.3
	_player.floor_max_angle = deg_to_rad(46.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	_player.add_child(shape)
	_player_visual = Node3D.new()
	_player.add_child(_player_visual)

	var hull: SurfaceTool = SpikeKit.begin()
	for leg_x: float in [-0.25, 0.25]:
		SpikeKit.add_box(hull, _at(leg_x, 0.45, 0.0), Vector3(0.28, 0.9, 0.38), 0.5)
	SpikeKit.add_box(hull, _at(0.0, 1.25, 0.0), Vector3(1.0, 0.8, 0.7), 0.5)
	SpikeKit.add_box(hull, _at(0.0, 1.85, -0.05), Vector3(0.5, 0.38, 0.5), 0.5)
	SpikeKit.add_box(hull, _at(0.45, 1.25, -0.55), Vector3(0.16, 0.16, 0.9), 0.5)
	var steel: ORMMaterial3D = SpikeKit.tinted_material("metal_plate", Color(0.85, 0.88, 0.95))
	_add_visual(SpikeKit.finish(hull, steel), _player_visual)
	var visor: SurfaceTool = SpikeKit.begin()
	SpikeKit.add_box(visor, _at(0.0, 1.88, -0.31), Vector3(0.4, 0.1, 0.04), 1.0)
	var visor_mesh: ArrayMesh = SpikeKit.finish(
		visor, SpikeKit.emissive_material(Color(0.2, 0.9, 1.0), 4.0)
	)
	_add_visual(visor_mesh, _player_visual).cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	add_child(_player)
	_player.global_position = start


func _build_droids() -> void:
	var hull: SurfaceTool = SpikeKit.begin()
	SpikeKit.add_box(hull, _at(0.0, 0.75, 0.0), Vector3(0.9, 0.55, 0.9), 0.5)
	SpikeKit.add_box(hull, _at(0.0, 1.17, -0.1), Vector3(0.55, 0.32, 0.5), 0.5)
	for corner: Vector2 in [
		Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)
	]:
		SpikeKit.add_box(hull, _at(corner.x, 0.25, corner.y), Vector3(0.14, 0.5, 0.14), 0.5)
	var dark_steel: ORMMaterial3D = SpikeKit.tinted_material("metal_plate", Color(0.3, 0.29, 0.3))
	var body_mesh: ArrayMesh = SpikeKit.finish(hull, dark_steel)
	var eye: SurfaceTool = SpikeKit.begin()
	SpikeKit.add_box(eye, _at(0.0, 1.2, -0.36), Vector3(0.38, 0.08, 0.04), 1.0)
	var eye_mesh: ArrayMesh = SpikeKit.finish(
		eye, SpikeKit.emissive_material(Color(1.0, 0.05, 0.12), 6.0)
	)
	for i in DROID_COUNT:
		var droid: SpikeDroid = SpikeDroid.new()
		droid.name = "Droid%d" % i
		droid.setup(body_mesh, eye_mesh)
		add_child(droid)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		droid.global_position = Vector3(side * randf_range(12.0, 28.0), 0.2, randf_range(-4.0, 4.0))
		_droids.append(droid)


func _build_tracers() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 1.0)
	mesh.material = SpikeKit.emissive_material(Color(1.0, 0.75, 0.35), 8.0)
	_tracers = MultiMesh.new()
	_tracers.transform_format = MultiMesh.TRANSFORM_3D
	_tracers.mesh = mesh
	_tracers.instance_count = TRACER_POOL
	_tracer_life.resize(TRACER_POOL)
	for i in TRACER_POOL:
		_tracers.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = _tracers
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-50.0, -5.0, -20.0), Vector3(100.0, 40.0, 40.0))
	add_child(mmi)


func _build_impacts() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat: StandardMaterial3D = SpikeKit.emissive_material(Color(1.0, 0.6, 0.2), 6.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	for i in IMPACT_POOL:
		var sparks: CPUParticles3D = CPUParticles3D.new()
		sparks.emitting = false
		sparks.one_shot = true
		sparks.amount = 10
		sparks.lifetime = 0.35
		sparks.explosiveness = 1.0
		sparks.spread = 50.0
		sparks.initial_velocity_min = 3.0
		sparks.initial_velocity_max = 6.0
		sparks.gravity = Vector3(0.0, -9.0, 0.0)
		sparks.mesh = quad
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sparks)
		_impacts.append(sparks)


## Dev aid: `-- --spike-shot` saves both camera views to user:// and quits.
func _auto_screenshots() -> void:
	for mode: Settings.CameraMode in [Settings.CameraMode.TACTICAL, Settings.CameraMode.SHOULDER]:
		Settings.set_camera_mode(mode)
		for i in 120:
			await RenderingServer.frame_post_draw
		_update_overlay()
		await RenderingServer.frame_post_draw
		var path: String = "user://spike_%s.png" % Settings.CameraMode.keys()[mode].to_lower()
		get_viewport().get_texture().get_image().save_png(path)
		var stats: String = _overlay.text.replace("\n", " | ")
		print("[SPIKE] ", ProjectSettings.globalize_path(path), " | ", stats)
	get_tree().quit()


func _add_visual(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))
