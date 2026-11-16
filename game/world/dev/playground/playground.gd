extends Node3D
## Dev playground (P1-01…04): HOLLOW + CameraRig in the spike street, no combat.
## The reticle is drawn where the aim lands, so it works the same in both modes.

const HINT_TEXT: String = "WASD move · Mouse/right stick aim · V camera · Esc free mouse"

@onready var _rig: CameraRig = $CameraRig
@onready var _reticle: Label = $HUD/Reticle
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	$HUD/Hint.text = HINT_TEXT
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _process(_delta: float) -> void:
	var aim: Vector3 = InputRouter.get_aim_target()
	_reticle.visible = not _rig.camera.is_position_behind(aim)
	_reticle.position = _rig.camera.unproject_position(aim) - _reticle.size * 0.5
	_info.text = (
		"Camera %s · Input %s · FPS %d"
		% [
			_rig.get_mode_name(),
			InputRouter.Device.keys()[InputRouter.active_device],
			Engine.get_frames_per_second()
		]
	)
