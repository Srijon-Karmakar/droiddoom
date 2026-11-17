class_name Hollow
extends CharacterBody3D
## HOLLOW, the player droid (P1-02). Camera-relative movement with
## acceleration and friction. The legs turn toward the move direction, the
## turret (upper body) turns toward the aim independently. Move and aim come
## from InputRouter only, so this works the same in every camera mode.

@export var stats: PlayerStats

## Player health. Max comes from `stats.max_hp`.
@onready var health: HealthComponent = $Health
## Primary gun (Pulse Rifle by default).
@onready var weapon: Weapon = $Turret/Muzzle/PrimaryWeapon
@onready var _legs: Node3D = $Legs
@onready var _turret: Node3D = $Turret
@onready var _muzzle: Marker3D = $Turret/Muzzle


func _ready() -> void:
	health.max_health = stats.max_hp
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	weapon.wielder = self
	weapon.set_exclude([get_rid()])


func _physics_process(delta: float) -> void:
	var wish: Vector3 = InputRouter.get_move_vector_world() * stats.move_speed
	var flat: Vector3 = step_velocity(
		Vector3(velocity.x, 0.0, velocity.z), wish, stats.acceleration, stats.friction, delta
	)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= stats.gravity * delta
	move_and_slide()
	if flat.length() > 0.5:
		var leg_yaw: float = atan2(-flat.x, -flat.z)
		_legs.rotation.y = rotate_angle_toward(
			_legs.rotation.y, leg_yaw, stats.leg_turn_speed * delta
		)


func _process(delta: float) -> void:
	var to_aim: Vector3 = InputRouter.get_aim_target() - global_position
	if Vector2(to_aim.x, to_aim.z).length() > 0.3:
		var aim_yaw: float = atan2(-to_aim.x, -to_aim.z) - global_rotation.y
		_turret.rotation.y = rotate_angle_toward(
			_turret.rotation.y, aim_yaw, stats.turret_turn_speed * delta
		)
	if InputRouter.is_primary_fire_held() and not health.is_dead():
		weapon.try_fire(get_muzzle_position(), InputRouter.get_aim_target())


## Takes knockback from a hit (horizontal push, m/s).
func apply_knockback(push: Vector3) -> void:
	velocity.x += push.x
	velocity.z += push.z


## World position where shots start.
func get_muzzle_position() -> Vector3:
	return _muzzle.global_position


## Horizontal direction the turret faces (unit vector).
func get_turret_forward() -> Vector3:
	return -_turret.global_basis.z


## Moves `current` horizontal velocity toward `wish`: accelerates while there is
## move input, brakes with friction when there is none.
static func step_velocity(
	current: Vector3, wish: Vector3, accel: float, friction: float, delta: float
) -> Vector3:
	var rate: float = accel if wish.length_squared() > 0.0001 else friction
	return current.move_toward(wish, rate * delta)


## Turns angle `from` toward `to` by at most `max_step` radians (shortest way).
static func rotate_angle_toward(from: float, to: float, max_step: float) -> float:
	var diff: float = wrapf(to - from, -PI, PI)
	if absf(diff) <= max_step:
		return wrapf(to, -PI, PI)
	return wrapf(from + signf(diff) * max_step, -PI, PI)


func _on_damaged(info: DamageInfo, final_amount: float) -> void:
	if info.knockback != Vector3.ZERO:
		apply_knockback(info.knockback)
	EventBus.player_damaged.emit(final_amount, info.type)


func _on_died(_info: DamageInfo) -> void:
	EventBus.player_died.emit()
