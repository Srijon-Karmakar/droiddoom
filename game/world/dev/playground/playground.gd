extends Node3D
## Dev playground (P1-01…07): HOLLOW + CameraRig + Pulse Rifle in the spike street,
## five target dummies. The reticle is drawn where the aim lands (both modes).

const HINT_TEXT: String = "WASD move · Mouse/right stick aim · LMB fire · V camera · Esc free mouse"

var _kills: int = 0

@onready var _rig: CameraRig = $CameraRig
@onready var _reticle: Label = $HUD/Reticle
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	$HUD/Hint.text = HINT_TEXT
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	EventBus.enemy_died.connect(func(_enemy: Node, _killer: Node) -> void: _kills += 1)


func _process(_delta: float) -> void:
	var aim: Vector3 = InputRouter.get_aim_target()
	_reticle.visible = not _rig.camera.is_position_behind(aim)
	_reticle.position = _rig.camera.unproject_position(aim) - _reticle.size * 0.5
	_info.text = (
		"Camera %s · Input %s · Kills %d · FPS %d"
		% [
			_rig.get_mode_name(),
			InputRouter.Device.keys()[InputRouter.active_device],
			_kills,
			Engine.get_frames_per_second()
		]
	)
