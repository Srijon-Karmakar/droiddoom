extends GutTest
## P1-07: hitscan weapon. Walls block shots, hurtboxes take damage, fire rate,
## crits, spread cone, faction mask, EventBus signals for FX.

const RIFLE: String = "res://data/weapons/weapon_pulse_rifle.tres"

var _root: Node3D
var _weapon: Weapon


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_weapon = Weapon.new()
	_weapon.data = (load(RIFLE) as WeaponData).duplicate()
	_weapon.data.spread_deg = 0.0
	_weapon.data.crit_chance = 0.0
	_weapon.target_mask = PhysicsLayers.ENEMIES
	_root.add_child(_weapon)


func test_shot_damages_target_and_emits_signals() -> void:
	var target: HealthComponent = _target(Vector3(0.0, 1.0, -10.0), PhysicsLayers.ENEMIES)
	watch_signals(EventBus)
	await wait_physics_frames(2)
	assert_true(_weapon.try_fire(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -10.0)))
	assert_eq(target.get_health(), 100.0 - _weapon.data.damage)
	assert_signal_emitted(EventBus, "weapon_fired")
	assert_signal_emitted(EventBus, "hit_landed")
	var params: Array = get_signal_parameters(EventBus, "hit_landed")
	assert_true(params[3], "on_target")


func test_wall_blocks_shot() -> void:
	var target: HealthComponent = _target(Vector3(0.0, 1.0, -10.0), PhysicsLayers.ENEMIES)
	_wall(Vector3(0.0, 1.0, -5.0))
	await wait_physics_frames(2)
	_weapon.try_fire(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -10.0))
	assert_eq(target.get_health(), 100.0)


func test_wrong_faction_is_not_hit() -> void:
	var ally: HealthComponent = _target(Vector3(0.0, 1.0, -10.0), PhysicsLayers.PLAYER)
	await wait_physics_frames(2)
	_weapon.try_fire(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -10.0))
	assert_eq(ally.get_health(), 100.0)


func test_fire_rate_limits_shots() -> void:
	await wait_physics_frames(1)
	assert_true(_weapon.try_fire(Vector3.ZERO, Vector3.FORWARD))
	assert_false(_weapon.try_fire(Vector3.ZERO, Vector3.FORWARD), "still cooling down")
	await wait_seconds(_weapon.data.fire_interval + 0.05)
	assert_true(_weapon.try_fire(Vector3.ZERO, Vector3.FORWARD))


func test_crit_multiplies_damage() -> void:
	_weapon.data.crit_chance = 1.0
	var target: HealthComponent = _target(Vector3(0.0, 1.0, -10.0), PhysicsLayers.ENEMIES)
	await wait_physics_frames(2)
	_weapon.try_fire(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -10.0))
	assert_eq(target.get_health(), 100.0 - _weapon.data.damage * _weapon.data.crit_multiplier)


func test_spread_stays_inside_cone() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dir: Vector3 = Vector3(0.3, 0.1, -1.0).normalized()
	var widest: float = 0.0
	for i in 500:
		var spread: Vector3 = Weapon.apply_spread(dir, 3.0, rng)
		assert_almost_eq(spread.length(), 1.0, 0.0001)
		widest = maxf(widest, rad_to_deg(dir.angle_to(spread)))
	assert_lt(widest, 3.0001)
	assert_gt(widest, 2.0, "uses the cone, not just the centre")


func _target(pos: Vector3, layer: int) -> HealthComponent:
	var actor: Node3D = Node3D.new()
	actor.position = pos
	_root.add_child(actor)
	var health: HealthComponent = HealthComponent.new()
	actor.add_child(health)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.collision_layer = layer
	hurtbox.collision_mask = 0
	hurtbox.health = health
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	hurtbox.add_child(shape)
	actor.add_child(hurtbox)
	return health


func _wall(pos: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.3)
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
