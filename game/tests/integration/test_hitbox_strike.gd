extends GutTest
## P1-06: HitboxComponent.strike() finds hurtboxes through the physics space,
## respects the faction mask, and hits each health once (best zone wins).

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func test_strike_hits_target_layer_once_with_best_zone() -> void:
	var enemy: HealthComponent = _actor(Vector3(1.0, 0.0, 0.0), PhysicsLayers.ENEMIES, [1.0, 2.0])
	var player: HealthComponent = _actor(Vector3(-1.0, 0.0, 0.0), PhysicsLayers.PLAYER, [1.0])
	var far_enemy: HealthComponent = _actor(Vector3(20.0, 0.0, 0.0), PhysicsLayers.ENEMIES, [1.0])
	var hitbox: HitboxComponent = _hitbox(3.0, PhysicsLayers.ENEMIES, 10.0)
	await wait_physics_frames(2)

	var hits: int = hitbox.strike()
	assert_eq(hits, 1, "one health in range on the enemy layer")
	assert_eq(enemy.get_health(), 80.0, "hit once, by the 2x zone")
	assert_eq(player.get_health(), 100.0, "player layer not in the mask")
	assert_eq(far_enemy.get_health(), 100.0, "out of range")


func test_strike_applies_resistances_of_victim() -> void:
	var enemy: HealthComponent = _actor(Vector3.ZERO, PhysicsLayers.ENEMIES, [1.0])
	enemy.resistances = DamageResistances.new()
	enemy.resistances.energy = 1.5
	var hitbox: HitboxComponent = _hitbox(2.0, PhysicsLayers.ENEMIES, 10.0)
	hitbox.damage_type = DamageInfo.Type.ENERGY
	await wait_physics_frames(2)
	hitbox.strike()
	assert_eq(enemy.get_health(), 85.0)


func test_strike_damages_hollow_and_reports_on_event_bus() -> void:
	var probe: FileAccess = FileAccess.open(
		"res://assets/textures/pbr/metal_plate/metal_plate_diff_1k.jpg", FileAccess.READ
	)
	if probe == null or probe.get_buffer(7).get_string_from_ascii() == "version":
		pending("Needs LFS art (CI runs without LFS)")
		return
	var hollow: Hollow = (load("res://actors/player/hollow.tscn") as PackedScene).instantiate()
	_root.add_child(hollow)
	var hitbox: HitboxComponent = _hitbox(2.0, PhysicsLayers.PLAYER, 25.0)
	hitbox.position = Vector3(0.0, 1.0, 1.0)
	hitbox.knockback = 5.0
	watch_signals(EventBus)
	await wait_physics_frames(2)
	hitbox.strike()
	assert_eq(hollow.health.get_health(), hollow.stats.max_hp - 25.0)
	assert_signal_emitted_with_parameters(
		EventBus, "player_damaged", [25.0, DamageInfo.Type.KINETIC]
	)
	assert_lt(hollow.velocity.z, -1.0, "knocked away from the blast (blast is on +Z)")


## Actor = Node3D with a HealthComponent and one hurtbox sphere per zone.
func _actor(pos: Vector3, layer: int, zones: Array) -> HealthComponent:
	var actor: Node3D = Node3D.new()
	actor.position = pos
	_root.add_child(actor)
	var health: HealthComponent = HealthComponent.new()
	actor.add_child(health)
	for zone: float in zones:
		var hurtbox: HurtboxComponent = HurtboxComponent.new()
		hurtbox.collision_layer = layer
		hurtbox.collision_mask = 0
		hurtbox.health = health
		hurtbox.zone_multiplier = zone
		hurtbox.add_child(_sphere(0.5))
		actor.add_child(hurtbox)
	return health


func _hitbox(radius: float, mask: int, damage: float) -> HitboxComponent:
	var hitbox: HitboxComponent = HitboxComponent.new()
	hitbox.collision_mask = mask
	hitbox.damage = damage
	hitbox.add_child(_sphere(radius))
	_root.add_child(hitbox)
	return hitbox


func _sphere(radius: float) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	return shape
