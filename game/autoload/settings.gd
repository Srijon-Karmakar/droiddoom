extends Node
## Player settings: graphics, audio, accessibility, controls and camera mode.
##
## Stub (P0-04). Persistence comes with SaveManager (P2-08). Settings UI comes in P2-10.

enum CameraMode { TACTICAL, SHOULDER }

## Active camera mode (D-013). Tactical is the default on every platform for now.
var camera_mode: CameraMode = CameraMode.TACTICAL
## Screen shake on/off (accessibility).
var screen_shake_enabled: bool = true
## Aim assist strength, 0.0 to 1.0.
var aim_assist: float = 0.5


## Switches the camera mode and notifies listeners via EventBus.
func set_camera_mode(mode: CameraMode) -> void:
	if mode == camera_mode:
		return
	camera_mode = mode
	EventBus.camera_mode_changed.emit(mode)


## Toggles between Tactical and Shoulder.
func toggle_camera_mode() -> void:
	if camera_mode == CameraMode.TACTICAL:
		set_camera_mode(CameraMode.SHOULDER)
	else:
		set_camera_mode(CameraMode.TACTICAL)
