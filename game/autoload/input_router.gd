extends Node
## Detects the active input device and serves camera-agnostic move and aim.
##
## Gameplay asks this autoload for movement and aim and never reads devices or
## cameras directly (AGENTS.md rule 6a). The active `CameraRig` registers here
## and supplies the aim target and the move basis for whichever mode is active.

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

## Device that produced the most recent meaningful input.
var active_device: Device = Device.KEYBOARD_MOUSE

var _rig: CameraRig


func _input(event: InputEvent) -> void:
	var device: Device = active_device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		device = Device.TOUCH
	elif event is InputEventJoypadButton:
		device = Device.GAMEPAD
	elif (
		event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3
	):
		device = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		device = Device.KEYBOARD_MOUSE
	if device != active_device:
		active_device = device
		EventBus.input_device_changed.emit(device)


## Called by a CameraRig when it enters the tree.
func register_camera_rig(rig: CameraRig) -> void:
	_rig = rig


## Called by a CameraRig when it leaves the tree.
func unregister_camera_rig(rig: CameraRig) -> void:
	if _rig == rig:
		_rig = null


## Movement input as a 2D vector (x = right, y = down/back), length ≤ 1.
func get_move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## Movement input in world space (XZ plane, length ≤ 1), relative to the
## active camera. Zero-yaw basis when no camera rig is registered.
func get_move_vector_world() -> Vector3:
	var yaw: float = _rig.get_move_yaw() if _rig != null else 0.0
	return move_to_world(get_move_vector(), yaw)


## Right-stick aim as a 2D vector (gamepad; touch sticks feed the same actions).
func get_stick_aim_vector() -> Vector2:
	return Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")


## World-space point the player is aiming at. `Vector3.ZERO` with no camera rig.
func get_aim_target() -> Vector3:
	return _rig.aim_target if _rig != null else Vector3.ZERO


## Unit direction from `from` toward the aim target (full 3D).
func get_aim_direction(from: Vector3) -> Vector3:
	var to_target: Vector3 = get_aim_target() - from
	return to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.FORWARD


## Converts a 2D move vector (x right, y back) to world XZ, rotated by `yaw`.
static func move_to_world(move: Vector2, yaw: float) -> Vector3:
	return Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, yaw)
