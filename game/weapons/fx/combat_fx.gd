class_name CombatFX
extends Node3D
## Draws every shot and impact in the level (one instance per level). Listens
## to EventBus, so weapons, enemies and the camera never know it exists.
## Cost: tracers = one MultiMesh per damage type (3 draw calls max), impacts =
## a fixed pool of CPUParticles3D (web-safe, no GPU particles). Particle count
## follows the quality preset's `particle_density`.

const TRACER_POOL: int = 32
const TRACER_LIFE: float = 0.06
const TRACER_THICKNESS: float = 0.035
const IMPACT_POOL: int = 16
const SPARKS_AT_FULL_DENSITY: int = 10
## Tracer and spark colour per DamageInfo.Type (GDD §4.2: yellow / orange / cyan).
const TYPE_COLORS: Array[Color] = [
	Color(1.0, 0.75, 0.35),
	Color(1.0, 0.42, 0.1),
	Color(0.3, 0.9, 1.0),
]
const GLOW_ENERGY: float = 8.0

var _tracers: Array[MultiMesh] = []
var _tracer_life: Array[PackedFloat32Array] = []
var _tracer_next: PackedInt32Array = PackedInt32Array()
var _spark_meshes: Array[QuadMesh] = []
var _impacts: ObjectPool


func _ready() -> void:
	for type_index in TYPE_COLORS.size():
		_build_tracers(TYPE_COLORS[type_index])
		_spark_meshes.append(_spark_mesh(TYPE_COLORS[type_index]))
	_impacts = ObjectPool.new(_new_sparks, IMPACT_POOL, self)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.hit_landed.connect(_on_hit_landed)
	EventBus.quality_preset_changed.connect(_on_quality_changed)
	_on_quality_changed(QualityManager.preset)


func _process(delta: float) -> void:
	for t in _tracers.size():
		var life: PackedFloat32Array = _tracer_life[t]
		for i in TRACER_POOL:
			if life[i] <= 0.0:
				continue
			life[i] -= delta
			if life[i] <= 0.0:
				_tracers[t].set_instance_transform(i, _hidden())
		_tracer_life[t] = life


## Number of tracers currently visible (debug/tests).
func get_live_tracer_count() -> int:
	var count: int = 0
	for life: PackedFloat32Array in _tracer_life:
		for v: float in life:
			if v > 0.0:
				count += 1
	return count


func _on_weapon_fired(from: Vector3, to: Vector3, damage_type: int) -> void:
	var length: float = from.distance_to(to)
	if length < 0.1:
		return
	var t: int = clampi(damage_type, 0, _tracers.size() - 1)
	var dir: Vector3 = (to - from) / length
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var basis: Basis = Basis.looking_at(dir, up).scaled(Vector3(1.0, 1.0, length))
	var slot: int = _tracer_next[t]
	_tracers[t].set_instance_transform(slot, Transform3D(basis, (from + to) * 0.5))
	_tracer_life[t][slot] = TRACER_LIFE
	_tracer_next[t] = (slot + 1) % TRACER_POOL


func _on_hit_landed(position: Vector3, normal: Vector3, damage_type: int, _on_target: bool) -> void:
	var sparks: CPUParticles3D = _impacts.acquire()
	sparks.mesh = _spark_meshes[clampi(damage_type, 0, _spark_meshes.size() - 1)]
	sparks.global_position = position + normal * 0.05
	sparks.direction = normal
	sparks.restart()


func _on_quality_changed(_preset: int) -> void:
	var density: float = (
		QualityManager.settings.particle_density if QualityManager.settings else 1.0
	)
	var amount: int = maxi(2, roundi(SPARKS_AT_FULL_DENSITY * density))
	for child: Node in get_children():
		var sparks: CPUParticles3D = child as CPUParticles3D
		if sparks != null and sparks.amount != amount:
			sparks.amount = amount


func _build_tracers(color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(TRACER_THICKNESS, TRACER_THICKNESS, 1.0)
	mesh.material = _glow_material(color)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = TRACER_POOL
	for i in TRACER_POOL:
		multimesh.set_instance_transform(i, _hidden())
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tracers can be anywhere in the level: never frustum-cull the whole set.
	instance.custom_aabb = AABB(Vector3(-500.0, -50.0, -500.0), Vector3(1000.0, 200.0, 1000.0))
	add_child(instance)
	_tracers.append(multimesh)
	var life: PackedFloat32Array = PackedFloat32Array()
	life.resize(TRACER_POOL)
	_tracer_life.append(life)
	_tracer_next.append(0)


func _spark_mesh(color: Color) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat: StandardMaterial3D = _glow_material(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	return quad


func _new_sparks() -> CPUParticles3D:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = SPARKS_AT_FULL_DENSITY
	sparks.lifetime = 0.35
	sparks.explosiveness = 1.0
	sparks.spread = 50.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 6.0
	sparks.gravity = Vector3(0.0, -9.0, 0.0)
	sparks.mesh = _spark_meshes[0]
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.finished.connect(func() -> void: _impacts.release(sparks))
	return sparks


static func _glow_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = GLOW_ENERGY
	return mat


static func _hidden() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
