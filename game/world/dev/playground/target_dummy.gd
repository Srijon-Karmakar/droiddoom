extends Node3D
## Dev target (P1-07): shows HP, has a body hurtbox and a 2x head weak spot,
## respawns after being destroyed. Dev-only: values are inline on purpose.

const MAX_HP: float = 60.0
const RESPAWN_DELAY: float = 2.0
const HIT_FLASH_TIME: float = 0.08

var _health: HealthComponent
var _visuals: Node3D
var _label: Label3D
var _hurtboxes: Array[HurtboxComponent] = []
var _body_material: StandardMaterial3D
var _flash: float = 0.0
var _respawn: float = 0.0


func _ready() -> void:
	_health = HealthComponent.new()
	_health.name = "Health"
	_health.max_health = MAX_HP
	add_child(_health)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_build_visuals()
	_hurtboxes.append(_add_hurtbox(Vector3(0.0, 1.0, 0.0), Vector3(0.7, 1.0, 0.5), 1.0, false))
	_hurtboxes.append(_add_hurtbox(Vector3(0.0, 1.75, 0.0), Vector3(0.4, 0.35, 0.4), 2.0, true))
	_update_label()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_body_material.emission_enabled = false
	if _respawn > 0.0:
		_respawn -= delta
		if _respawn <= 0.0:
			_set_alive(true)
			_health.reset()
			_update_label()


func _on_damaged(_info: DamageInfo, _amount: float) -> void:
	_body_material.emission_enabled = true
	_flash = HIT_FLASH_TIME
	_update_label()


func _on_died(info: DamageInfo) -> void:
	_set_alive(false)
	_respawn = RESPAWN_DELAY
	EventBus.enemy_died.emit(self, info.source)


func _set_alive(alive: bool) -> void:
	_visuals.visible = alive
	_label.visible = alive
	for hurtbox: HurtboxComponent in _hurtboxes:
		hurtbox.collision_layer = PhysicsLayers.ENEMIES if alive else 0


func _update_label() -> void:
	_label.text = "%d" % ceili(_health.get_health())


func _add_hurtbox(
	center: Vector3, size: Vector3, multiplier: float, weak: bool
) -> HurtboxComponent:
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.collision_layer = PhysicsLayers.ENEMIES
	hurtbox.collision_mask = 0
	hurtbox.health = _health
	hurtbox.zone_multiplier = multiplier
	hurtbox.is_weak_spot = weak
	hurtbox.position = center
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	hurtbox.add_child(shape)
	add_child(hurtbox)
	return hurtbox


func _build_visuals() -> void:
	_visuals = Node3D.new()
	add_child(_visuals)
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.25, 0.24, 0.23)
	_body_material.metallic = 0.6
	_body_material.roughness = 0.5
	_body_material.emission = Color(1.0, 0.3, 0.2)
	_body_material.emission_energy_multiplier = 2.0
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.4, 0.02, 0.04)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.06, 0.12)
	red.emission_energy_multiplier = 4.0
	_box(Vector3(0.0, 0.25, 0.0), Vector3(0.12, 0.5, 0.12), _body_material)
	_box(Vector3(0.0, 1.0, 0.0), Vector3(0.7, 1.0, 0.5), _body_material)
	_box(Vector3(0.0, 1.75, 0.0), Vector3(0.4, 0.35, 0.4), _body_material)
	_box(Vector3(0.0, 1.78, -0.21), Vector3(0.3, 0.06, 0.03), red)
	_label = Label3D.new()
	_label.position = Vector3(0.0, 2.3, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 8
	_label.no_depth_test = true
	add_child(_label)


func _box(center: Vector3, size: Vector3, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	_visuals.add_child(instance)
