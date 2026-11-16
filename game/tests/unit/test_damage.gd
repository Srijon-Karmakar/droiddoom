extends GutTest
## P1-06: damage math (resistances, zone multipliers) and HealthComponent rules.

var _health: HealthComponent


func before_each() -> void:
	_health = HealthComponent.new()
	_health.max_health = 100.0
	add_child_autofree(_health)


func test_resolve_plain_hit() -> void:
	assert_eq(DamageInfo.resolve(10.0, DamageInfo.Type.KINETIC, 1.0, null), 10.0)


func test_resolve_applies_zone_and_resistance() -> void:
	var r: DamageResistances = DamageResistances.new()
	r.energy = 1.5
	r.kinetic = 0.5
	assert_almost_eq(DamageInfo.resolve(10.0, DamageInfo.Type.ENERGY, 2.0, r), 30.0, 0.001)
	assert_almost_eq(DamageInfo.resolve(10.0, DamageInfo.Type.KINETIC, 1.0, r), 5.0, 0.001)
	assert_almost_eq(DamageInfo.resolve(10.0, DamageInfo.Type.EMP, 1.0, r), 10.0, 0.001)


func test_resolve_immune_and_never_negative() -> void:
	var r: DamageResistances = DamageResistances.new()
	r.emp = 0.0
	assert_eq(DamageInfo.resolve(10.0, DamageInfo.Type.EMP, 1.0, r), 0.0)
	assert_eq(DamageInfo.resolve(-5.0, DamageInfo.Type.KINETIC, 1.0, null), 0.0)


func test_health_starts_full() -> void:
	assert_eq(_health.get_health(), 100.0)
	assert_eq(_health.get_ratio(), 1.0)


func test_damage_reduces_health_and_emits() -> void:
	watch_signals(_health)
	var taken: float = _health.apply_damage(_hit(30.0))
	assert_eq(taken, 30.0)
	assert_eq(_health.get_health(), 70.0)
	assert_signal_emitted_with_parameters(_health, "health_changed", [100.0, 70.0])
	assert_signal_emit_count(_health, "damaged", 1)
	assert_signal_not_emitted(_health, "died")


func test_overkill_reports_only_health_lost() -> void:
	_health.apply_damage(_hit(90.0))
	assert_eq(_health.apply_damage(_hit(50.0)), 10.0, "only 10 HP were left")


func test_dies_exactly_once() -> void:
	watch_signals(_health)
	_health.apply_damage(_hit(150.0))
	_health.apply_damage(_hit(10.0))
	assert_true(_health.is_dead())
	assert_eq(_health.get_health(), 0.0)
	assert_signal_emit_count(_health, "died", 1)


func test_invulnerable_takes_nothing() -> void:
	_health.invulnerable = true
	assert_eq(_health.apply_damage(_hit(50.0)), 0.0)
	assert_eq(_health.get_health(), 100.0)


func test_resistances_apply_through_health() -> void:
	_health.resistances = DamageResistances.new()
	_health.resistances.kinetic = 0.25
	assert_eq(_health.apply_damage(_hit(40.0)), 10.0)


func test_heal_caps_at_max_and_not_when_dead() -> void:
	_health.apply_damage(_hit(30.0))
	_health.heal(50.0)
	assert_eq(_health.get_health(), 100.0)
	_health.apply_damage(_hit(500.0))
	_health.heal(50.0)
	assert_eq(_health.get_health(), 0.0, "dead actors don't heal")


func test_reset_revives() -> void:
	_health.apply_damage(_hit(500.0))
	_health.invulnerable = true
	_health.reset()
	assert_false(_health.is_dead())
	assert_false(_health.invulnerable)
	assert_eq(_health.get_health(), 100.0)


func test_hurtbox_weak_spot_multiplies_and_marks_crit() -> void:
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.health = _health
	hurtbox.zone_multiplier = 2.0
	hurtbox.is_weak_spot = true
	add_child_autofree(hurtbox)
	var info: DamageInfo = _hit(10.0)
	assert_eq(hurtbox.take_hit(info), 20.0)
	assert_true(info.crit)


func _hit(amount: float) -> DamageInfo:
	return DamageInfo.create(amount, DamageInfo.Type.KINETIC)
