extends Node3D
## Phase 0 scaffold scene. TEMPORARY: the main menu replaces it in P2-10.
##
## Proves that the project boots on the Compatibility renderer, the autoloads
## load and the input actions work.
## Controls: WASD / left stick moves the placeholder droid, V switches the
## camera mode (Tactical/Shoulder), F3 toggles the info overlay, Esc quits
## (desktop only).

const MOVE_SPEED: float = 6.0
const TACTICAL_PITCH_DEG: float = 55.0
const TACTICAL_DISTANCE: float = 14.0
const SHOULDER_OFFSET: Vector3 = Vector3(0.9, 2.6, 3.6)
const SHOULDER_LOOK: Vector3 = Vector3(0.0, 1.8, -8.0)
const CAMERA_SMOOTHING: float = 6.0
const ENEMY_COUNT: int = 8
const ENEMY_RING_RADIUS: float = 12.0

var _enemies: Array[Node3D] = []

@onready var _droid: Node3D = $Droid
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	_spawn_placeholder_enemies()
	_update_camera(1.0)


func _process(delta: float) -> void:
	var move: Vector2 = InputRouter.get_move_vector()
	_droid.position += Vector3(move.x, 0.0, move.y) * MOVE_SPEED * delta
	if move.length() > 0.1:
		_droid.rotation.y = atan2(-move.x, -move.y)
	for i in _enemies.size():
		_enemies[i].rotation.y += delta * (0.5 + 0.1 * i)
	_update_camera(minf(1.0, delta * CAMERA_SMOOTHING))
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"switch_camera"):
		Settings.toggle_camera_mode()
	elif event.is_action_pressed(&"toggle_debug"):
		_info.visible = not _info.visible
	elif event.is_action_pressed(&"pause") and not OS.has_feature("web"):
		get_tree().quit()


func _update_camera(weight: float) -> void:
	var target: Vector3 = _droid.global_position
	var desired: Transform3D
	if Settings.camera_mode == Settings.CameraMode.TACTICAL:
		var pitch: float = deg_to_rad(TACTICAL_PITCH_DEG)
		var offset: Vector3 = Vector3(0.0, sin(pitch), cos(pitch)) * TACTICAL_DISTANCE
		desired = Transform3D(Basis(), target + offset).looking_at(target + Vector3.UP, Vector3.UP)
	else:
		var droid_basis: Basis = _droid.global_transform.basis
		var eye: Vector3 = target + droid_basis * SHOULDER_OFFSET
		var look: Vector3 = target + droid_basis * SHOULDER_LOOK
		desired = Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
	_camera.global_transform = _camera.global_transform.interpolate_with(desired, weight)


func _update_info() -> void:
	if not _info.visible:
		return
	var version: String = Engine.get_version_info()["string"]
	var renderer: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	var lines: PackedStringArray = [
		"DROIDOOM — Phase 0 scaffold (temporary test scene)",
		(
			"Godot %s  |  Renderer: %s  |  Platform: %s"
			% [version, renderer, PlatformServices.get_platform_id()]
		),
		(
			"GPU: %s  |  Preset: %s  |  FPS: %d"
			% [
				QualityManager.get_gpu_name(),
				QualityManager.get_preset_name(),
				Engine.get_frames_per_second(),
			]
		),
		(
			"Camera: %s  |  Input: %s"
			% [
				Settings.CameraMode.keys()[Settings.camera_mode],
				InputRouter.Device.keys()[InputRouter.active_device],
			]
		),
		"WASD move  •  V switch camera  •  F3 hide info  •  Esc quit",
	]
	_info.text = "\n".join(lines)


func _spawn_placeholder_enemies() -> void:
	var hull: StandardMaterial3D = StandardMaterial3D.new()
	hull.albedo_color = Color(0.22, 0.2, 0.21)
	hull.metallic = 0.7
	hull.roughness = 0.45
	var eye: StandardMaterial3D = StandardMaterial3D.new()
	eye.albedo_color = Color(1.0, 0.1, 0.25)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.1, 0.25)
	eye.emission_energy_multiplier = 4.0

	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(0.9, 0.9, 0.9)
	body_mesh.material = hull
	var eye_mesh: BoxMesh = BoxMesh.new()
	eye_mesh.size = Vector3(0.5, 0.12, 0.05)
	eye_mesh.material = eye

	for i in ENEMY_COUNT:
		var angle: float = TAU * float(i) / float(ENEMY_COUNT)
		var enemy: Node3D = Node3D.new()
		enemy.name = "AxiomDroid%d" % i
		enemy.position = Vector3(cos(angle), 0.0, sin(angle)) * ENEMY_RING_RADIUS
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = body_mesh
		body.position.y = 0.6
		enemy.add_child(body)
		var visor: MeshInstance3D = MeshInstance3D.new()
		visor.mesh = eye_mesh
		visor.position = Vector3(0.0, 0.75, -0.46)
		enemy.add_child(visor)
		add_child(enemy)
		_enemies.append(enemy)
