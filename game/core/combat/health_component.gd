class_name HealthComponent
extends Node
## Hit points for any damageable actor (TDD §3.1 composition). Receives
## DamageInfo from HurtboxComponents. Dies exactly once until `reset()`.
## The owning actor listens to `died` and forwards to EventBus if needed.

signal health_changed(old_value: float, new_value: float)
## Emitted for every hit that dealt damage (after multipliers).
signal damaged(info: DamageInfo, final_amount: float)
signal died(info: DamageInfo)

@export var max_health: float = 100.0
## Optional per-type multipliers. Null = take normal damage from everything.
@export var resistances: DamageResistances

## True while no damage is taken (dash i-frames, spawn protection).
var invulnerable: bool = false

var _health: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_health = max_health


## Current hit points.
func get_health() -> float:
	return _health


## 0..1 share of max health, for health bars.
func get_ratio() -> float:
	return _health / max_health if max_health > 0.0 else 0.0


func is_dead() -> bool:
	return _dead


## Applies a hit. `zone_multiplier` comes from the hurtbox (weak spots).
## Returns the damage actually taken (0 if dead or invulnerable).
func apply_damage(info: DamageInfo, zone_multiplier: float = 1.0) -> float:
	if _dead or invulnerable:
		return 0.0
	var final_amount: float = DamageInfo.resolve(
		info.amount, info.type, zone_multiplier, resistances
	)
	if final_amount <= 0.0:
		return 0.0
	var old: float = _health
	_health = maxf(0.0, _health - final_amount)
	var taken: float = old - _health
	health_changed.emit(old, _health)
	damaged.emit(info, taken)
	if _health <= 0.0:
		_dead = true
		died.emit(info)
	return taken


## Restores health, capped at max. Does nothing once dead.
func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	var old: float = _health
	_health = minf(max_health, _health + amount)
	if _health != old:
		health_changed.emit(old, _health)


## Full health, alive again (pooled enemies, player respawn).
func reset() -> void:
	var old: float = _health
	_dead = false
	invulnerable = false
	_health = max_health
	if _health != old:
		health_changed.emit(old, _health)
