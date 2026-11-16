class_name HurtboxComponent
extends Area3D
## Where an actor can be hit. An Area3D on the actor's faction layer
## (PLAYER, ENEMIES or ALLIES) that only needs to be *found* by hitscan rays
## and hitbox queries, so `monitoring` is off (cheap). Forwards hits to a
## HealthComponent. Several hurtboxes can share one health (weak spots).

## Health that receives the damage.
@export var health: HealthComponent
## Damage multiplier for this zone (e.g. 2.0 for a weak spot).
@export var zone_multiplier: float = 1.0
## Weak-spot hits count as critical for VFX/SFX.
@export var is_weak_spot: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true


## Applies a hit to the linked health. Returns the damage actually taken.
func take_hit(info: DamageInfo) -> float:
	if health == null:
		return 0.0
	if is_weak_spot:
		info.crit = true
	return health.apply_damage(info, zone_multiplier)


## Actor that owns this hurtbox (the health's parent), or null.
func get_actor() -> Node:
	return health.get_parent() if health != null else null
