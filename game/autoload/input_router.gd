extends Node
## Detects the active input device and exposes camera-agnostic input vectors.
##
## Gameplay code asks this autoload for movement and aim and never reads
## devices directly (AGENTS.md rule 6a). Camera-aware aim comes in P1-01.

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

## Device that produced the most recent meaningful input.
var active_device: Device = Device.KEYBOARD_MOUSE


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


## Movement input as a 2D vector (x = right, y = down/back), length ≤ 1.
func get_move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## Right-stick aim as a 2D vector (gamepad only). Mouse/touch aim comes in P1-01.
func get_stick_aim_vector() -> Vector2:
	return Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
