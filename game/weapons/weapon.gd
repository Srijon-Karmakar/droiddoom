class_name Weapon
extends Node3D
## A hitscan gun (P1-07). The owner decides when to pull the trigger and
## passes the muzzle and the aim point (from InputRouter for the player, from
## AI for enemies), so the weapon itself is camera-agnostic. Visuals and audio
## react to EventBus signals; the weapon draws nothing.

signal fired(from: Vector3, to: Vector3)

@export var data: WeaponData
## Faction layers this weapon damages (hurtbox layers).
@export_flags_3d_physics var target_mask: int = PhysicsLayers.ENEMIES
## Who gets credit for hits. Defaults to the parent chain's first actor.
@export var wielder: Node

## Random source for spread and crits (seed it in tests).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _cooldown: float = 0.0
var _exclude: Array[RID] = []


func _ready() -> void:
	if wielder == null:
		wielder = owner if owner != null else get_parent()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## Bodies the shot passes through (the wielder's own colliders).
func set_exclude(rids: Array[RID]) -> void:
	_exclude = rids


func can_fire() -> bool:
	return _cooldown <= 0.0


## Fires one shot from `from` toward `aim_point` if off cooldown.
## Returns true if a shot was fired.
func try_fire(from: Vector3, aim_point: Vector3) -> bool:
	if not can_fire():
		return false
	_cooldown = data.fire_interval
	var dir: Vector3 = aim_point - from
	dir = dir.normalized() if dir.length() > 0.01 else -global_basis.z
	dir = apply_spread(dir, data.spread_deg, rng)
	var to: Vector3 = from + dir * data.max_range
	var hit: Dictionary = Hitscan.cast(
		get_world_3d().direct_space_state, from, to, target_mask, _exclude
	)
	var end: Vector3 = to
	if not hit.is_empty():
		end = hit["position"]
		var hurtbox: HurtboxComponent = hit["hurtbox"]
		if hurtbox != null:
			hurtbox.take_hit(_make_damage(end, dir))
		EventBus.hit_landed.emit(end, hit["normal"], data.damage_type, hurtbox != null)
	EventBus.weapon_fired.emit(from, end, data.damage_type)
	fired.emit(from, end)
	return true


## Rotates `dir` by a random angle inside a cone of `spread_deg` (half-angle).
static func apply_spread(dir: Vector3, spread_deg: float, random: RandomNumberGenerator) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var tilted: Vector3 = dir.rotated(side, deg_to_rad(random.randf_range(0.0, spread_deg)))
	return tilted.rotated(dir, random.randf_range(0.0, TAU)).normalized()


func _make_damage(at: Vector3, dir: Vector3) -> DamageInfo:
	var info: DamageInfo = DamageInfo.create(data.damage, data.damage_type, wielder, at)
	if rng.randf() < data.crit_chance:
		info.amount *= data.crit_multiplier
		info.crit = true
	if data.knockback > 0.0:
		info.knockback = Vector3(dir.x, 0.0, dir.z).normalized() * data.knockback
	return info
