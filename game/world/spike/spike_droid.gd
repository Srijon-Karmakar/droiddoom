class_name SpikeDroid
extends CharacterBody3D
## Placeholder AXIOM droid for the Phase 0.5 spike (P05-03): rigid parts, simple chase AI.
##
## The spawner calls `think()` at a low rate (10–20 Hz). Movement runs every
## physics frame. TEST CODE for the web 3D feasibility gate. Not production.

signal died(droid: SpikeDroid)

const SPEED: float = 3.2
const MAX_HP: int = 3
const GRAVITY: float = 20.0
const STOP_DISTANCE: float = 1.4
const SEPARATION: float = 1.6
const TURN_RATE: float = 8.0
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMIES: int = 8

var hp: int = MAX_HP
var alive: bool = true

var _desired: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _hit_timer: float = 0.0
var _visual: Node3D


## Builds collision + visuals from shared meshes (one body draw call + one eye draw call).
func setup(body_mesh: Mesh, eye_mesh: Mesh) -> void:
	collision_layer = LAYER_ENEMIES
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ENEMIES
	floor_snap_length = 0.3
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = body_mesh
	_visual.add_child(body)
	var eye: MeshInstance3D = MeshInstance3D.new()
	eye.mesh = eye_mesh
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(eye)


## AI tick: steer toward the target and away from close neighbours.
func think(target: Vector3, neighbours: Array[SpikeDroid]) -> void:
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	var chase: Vector3 = Vector3.ZERO
	if to_target.length() > STOP_DISTANCE:
		chase = to_target.normalized()
	var push: Vector3 = Vector3.ZERO
	for other: SpikeDroid in neighbours:
		if other == self or not other.alive:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var dist: float = away.length()
		if dist < SEPARATION and dist > 0.001:
			push += away / dist * (SEPARATION - dist)
	_desired = (chase + push * 0.8).limit_length(1.0) * SPEED
	if to_target.length() > 0.1:
		_yaw = atan2(-to_target.x, -to_target.z)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	velocity.x = _desired.x
	velocity.z = _desired.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _yaw, minf(1.0, delta * TURN_RATE))
	if _hit_timer > 0.0:
		_hit_timer -= delta
		_visual.scale = Vector3.ONE * (1.0 + _hit_timer)
	else:
		_visual.scale = Vector3.ONE


## Applies damage. Returns true if this hit destroyed the droid.
func take_hit(damage: int) -> bool:
	if not alive:
		return false
	hp -= damage
	_hit_timer = 0.12
	if hp <= 0:
		alive = false
		visible = false
		collision_layer = 0
		collision_mask = 0
		died.emit(self)
		return true
	return false


## Brings the droid back at full health.
func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	hp = MAX_HP
	alive = true
	visible = true
	collision_layer = LAYER_ENEMIES
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ENEMIES
