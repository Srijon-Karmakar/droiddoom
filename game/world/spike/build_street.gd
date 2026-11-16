extends SceneTree
## Generates the Phase 0.5 test sector: a ruined street (P05-01), lit for baking (P05-02).
##
## Run (editor binary, needed for lightmap UV unwrapping):
##   godot_console --headless --path game -s res://world/spike/build_street.gd
## Output: res://world/spike/street_sector.scn. Then bake its LightmapGI in a
## Forward+ editor (D-022). TEST CODE for the web 3D feasibility gate. Not production.

const OUT_PATH: String = "res://world/spike/street_sector.scn"
const SKY_PATH: String = "res://assets/textures/sky/kloppenheim_06_puresky_2k.hdr"
const PROP_PATH: String = "res://assets/models/props/%s/%s_1k.gltf"
const STREET_LEN: float = 72.0
const BLOCK_X: float = 32.0
const ROAD_HALF: float = 5.0
const WALK_W: float = 3.0
const FACADE_Z: float = 8.0
const WALL_T: float = 0.4
const CORE_DEPTH: float = 7.6
const SEG_LEN: float = 8.0
const FLOOR_H: float = 3.5
const LIGHTMAP_TEXEL: float = 0.4
const LAYER_WORLD: int = 1

var _root: Node3D
var _collision: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _tools: Dictionary = {}


func _init() -> void:
	_rng.seed = 7
	_root = Node3D.new()
	_root.name = "StreetSector"
	_collision = Node3D.new()
	_collision.name = "Collision"
	_add(_collision)
	for tex: String in [
		"asphalt_02",
		"concrete_floor_worn_001",
		"cracked_concrete_wall",
		"red_brick_03",
		"rusty_metal_02",
		"corrugated_iron",
	]:
		_mats[tex] = SpikeKit.pbr_material(tex)
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.03, 0.035, 0.04)
	glass.roughness = 0.12
	_mats["glass"] = glass
	_mats["rubble"] = SpikeKit.tinted_material("cracked_concrete_wall", Color(0.62, 0.6, 0.58))
	_mats["axiom_red"] = SpikeKit.emissive_material(Color(1.0, 0.06, 0.12), 5.0)

	_build_environment()
	_build_ground()
	for side: int in [-1, 1]:
		for i in int(BLOCK_X * 2.0 / SEG_LEN):
			_build_segment(side, -BLOCK_X + SEG_LEN * (i + 0.5))
	_build_barricades()
	_build_rubble()
	_build_pylons()
	_flush_static_meshes()
	_build_props()
	_build_markers()
	_build_gi()

	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("[BUILD] street sector saved to %s: %s" % [OUT_PATH, error_string(err)])
	_root.free()
	quit(0 if err == OK else 1)


func _build_environment() -> void:
	var sky_mat: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	sky_mat.panorama = load(SKY_PATH)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.55, 0.6)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.05
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_add(world_env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-30.0, 70.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(sun)


func _build_ground() -> void:
	var road: SurfaceTool = _tool("road", "asphalt_02")
	SpikeKit.add_box(road, _at(0.0, -0.15, 0.0), Vector3(STREET_LEN, 0.3, ROAD_HALF * 2.0), 4.0)
	_collider(_at(0.0, -0.15, 0.0), Vector3(STREET_LEN, 0.3, ROAD_HALF * 2.0))
	var walk: SurfaceTool = _tool("walk", "concrete_floor_worn_001")
	for side: int in [-1, 1]:
		var z: float = side * (ROAD_HALF + WALK_W * 0.5)
		SpikeKit.add_box(walk, _at(0.0, 0.0, z), Vector3(STREET_LEN, 0.24, WALK_W), 2.5)
		_collider(_at(0.0, 0.0, z), Vector3(STREET_LEN, 0.24, WALK_W))


## One 8 m building segment: facade with piers, sills, lintels, windows and a solid core.
func _build_segment(side: int, cx: float) -> void:
	var wall_mat: String = "red_brick_03" if _rng.randf() < 0.5 else "cracked_concrete_wall"
	var wall: SurfaceTool = _tool("wall_%d_%s" % [side, wall_mat], wall_mat)
	var floors: int = _rng.randi_range(2, 4)
	var ruined: bool = _rng.randf() < 0.35
	var top: float = floors * FLOOR_H
	var wall_z: float = side * (FACADE_Z + WALL_T * 0.5)
	var core_h: float = top - (_rng.randf_range(1.5, 3.0) if ruined else 0.0)
	var core_z: float = side * (FACADE_Z + WALL_T + CORE_DEPTH * 0.5)
	SpikeKit.add_box(wall, _at(cx, core_h * 0.5, core_z), Vector3(SEG_LEN, core_h, CORE_DEPTH), 3.0)
	_collider(_at(cx, top * 0.5, side * (FACADE_Z + 4.0)), Vector3(SEG_LEN, top, 8.0))

	# Piers [x0, x1] and window gaps between them, in segment-local x.
	var piers: Array[Vector2] = [Vector2(-4.0, -2.5), Vector2(-0.5, 0.5), Vector2(2.5, 4.0)]
	var windows: Array[Vector2] = [Vector2(-2.5, -0.5), Vector2(0.5, 2.5)]
	for f in floors:
		var y0: float = f * FLOOR_H
		var broken: bool = ruined and f == floors - 1
		for p: Vector2 in piers:
			var h: float = _rng.randf_range(0.6, FLOOR_H) if broken else FLOOR_H
			_wall_box(wall, cx + (p.x + p.y) * 0.5, y0, h, p.y - p.x, wall_z)
		if f == 0:
			_ground_floor(side, cx, wall, wall_z)
			continue
		for w: Vector2 in windows:
			var wx: float = cx + (w.x + w.y) * 0.5
			_wall_box(wall, wx, y0, 1.0, w.y - w.x, wall_z)
			if not broken:
				_wall_box(wall, wx, y0 + 2.6, FLOOR_H - 2.6, w.y - w.x, wall_z)
				_window_pane(side, wx, y0 + 1.0, w.y - w.x)
	if not ruined:
		_wall_box(wall, cx, top, 0.5, SEG_LEN, wall_z)
	else:
		_rubble_pile(Vector3(cx, 0.12, side * (ROAD_HALF + WALK_W * 0.6)), 10)


func _ground_floor(side: int, cx: float, wall: SurfaceTool, wall_z: float) -> void:
	# Shop front: the two windows merge into one 5 m opening with a rusty shutter.
	_wall_box(wall, cx, 0.0, 3.0, 1.0, wall_z)
	_wall_box(wall, cx, 3.0, 0.5, 5.0, wall_z)
	var shutter: SurfaceTool = _tool("shutter", "corrugated_iron")
	var drop: float = _rng.randf_range(1.6, 3.0)
	SpikeKit.add_box(
		shutter,
		_at(cx, 3.0 - drop * 0.5, side * (FACADE_Z + WALL_T * 0.8)),
		Vector3(5.0, drop, 0.06),
		2.0
	)


func _window_pane(side: int, wx: float, y: float, width: float) -> void:
	var r: float = _rng.randf()
	var key: String = "corrugated_iron" if r < 0.45 else "glass"
	var st: SurfaceTool = _tool("pane_" + key, key)
	SpikeKit.add_box(
		st, _at(wx, y + 0.8, side * (FACADE_Z + WALL_T * 0.75)), Vector3(width, 1.6, 0.05), 2.0
	)


func _wall_box(st: SurfaceTool, x: float, y0: float, h: float, w: float, z: float) -> void:
	SpikeKit.add_box(st, _at(x, y0 + h * 0.5, z), Vector3(w, h, WALL_T), 3.0)


func _build_barricades() -> void:
	var blocks: SurfaceTool = _tool("barricade_blocks", "cracked_concrete_wall")
	var sheets: SurfaceTool = _tool("barricade_sheets", "corrugated_iron")
	for end: int in [-1, 1]:
		var x: float = end * BLOCK_X
		_collider(_at(x, 1.5, 0.0), Vector3(1.6, 3.0, FACADE_Z * 2.0))
		var z: float = -FACADE_Z + 1.0
		while z < FACADE_Z - 0.5:
			var rot: Basis = Basis(Vector3.UP, _rng.randf_range(-0.15, 0.15))
			SpikeKit.add_box(
				blocks, Transform3D(rot, Vector3(x, 0.5, z)), Vector3(0.8, 1.0, 2.0), 2.0
			)
			if _rng.randf() < 0.6:
				var tilt: Basis = Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25)) * rot
				SpikeKit.add_box(
					sheets,
					Transform3D(tilt, Vector3(x - end * 0.5, 1.5, z)),
					Vector3(0.05, 2.6, 2.0),
					2.0
				)
			z += 2.1


func _build_rubble() -> void:
	for i in 6:
		var spot: Vector3 = Vector3(
			_rng.randf_range(-26.0, 26.0), 0.0, _rng.randf_range(-ROAD_HALF + 1.0, ROAD_HALF - 1.0)
		)
		_rubble_pile(spot, 8)


func _rubble_pile(center: Vector3, count: int) -> void:
	var st: SurfaceTool = _tool("rubble", "rubble")
	for i in count:
		var size: Vector3 = Vector3(
			_rng.randf_range(0.2, 0.8), _rng.randf_range(0.15, 0.45), _rng.randf_range(0.2, 0.7)
		)
		var euler: Vector3 = Vector3(
			_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.6, 0.6)
		)
		var offset: Vector3 = Vector3(_rng.randf_range(-1.4, 1.4), 0.0, _rng.randf_range(-0.9, 0.9))
		var pos: Vector3 = center + offset + Vector3(0.0, size.y * 0.35, 0.0)
		SpikeKit.add_box(st, Transform3D(Basis.from_euler(euler), pos), size, 1.5)


## AXIOM pylons: rusty poles with a red emissive lamp and a baked red light.
func _build_pylons() -> void:
	var metal: SurfaceTool = _tool("pylon_metal", "rusty_metal_02")
	var lamp: SurfaceTool = _tool("pylon_lamp", "axiom_red")
	var i: int = 0
	for x: float in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		var side: int = 1 if i % 2 == 0 else -1
		i += 1
		var z: float = side * (ROAD_HALF + 0.5)
		SpikeKit.add_box(metal, _at(x, 2.35, z), Vector3(0.25, 4.5, 0.25), 1.0)
		SpikeKit.add_box(metal, _at(x, 4.7, z - side * 0.3), Vector3(0.7, 0.3, 1.1), 1.0)
		SpikeKit.add_box(lamp, _at(x, 4.5, z - side * 0.3), Vector3(0.5, 0.1, 0.8), 1.0)
		_collider(_at(x, 2.35, z), Vector3(0.3, 4.7, 0.3))
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "AxiomLight%d" % i
		light.position = Vector3(x, 4.2, z - side * 0.3)
		light.light_color = Color(1.0, 0.1, 0.15)
		light.light_energy = 1.6
		light.omni_range = 7.0
		light.light_bake_mode = Light3D.BAKE_STATIC
		_add(light)
	# Red scanner strips on a few facades.
	for x: float in [-20.0, 4.0, 28.0]:
		var side: int = -1 if x < 0.0 else 1
		SpikeKit.add_box(lamp, _at(x, 4.2, side * (FACADE_Z - 0.02)), Vector3(5.0, 0.12, 0.04), 1.0)


func _build_props() -> void:
	var props: Node3D = Node3D.new()
	props.name = "Props"
	_add(props)
	var cars: Array[Vector4] = [
		Vector4(-14.0, 0.0, -2.2, 12.0),
		Vector4(9.0, 0.0, 2.6, 168.0),
		Vector4(21.0, 0.0, -1.2, -28.0)
	]
	for c: Vector4 in cars:
		_place_prop(props, "covered_car", Vector3(c.x, c.y, c.z), c.w, Vector3.ZERO)
	for i in 8:
		var side: int = 1 if i % 2 == 0 else -1
		var pos: Vector3 = Vector3(
			_rng.randf_range(-28.0, 28.0), 0.12, side * _rng.randf_range(5.6, 7.4)
		)
		var tipped: bool = _rng.randf() < 0.3
		var tilt: Vector3 = Vector3(90.0, 0.0, 0.0) if tipped else Vector3.ZERO
		_place_prop(
			props,
			"barrel_03",
			pos + Vector3(0.0, 0.3 if tipped else 0.0, 0.0),
			_rng.randf_range(0.0, 360.0),
			tilt
		)
	for i in 6:
		var pos: Vector3 = Vector3(_rng.randf_range(-28.0, 28.0), 0.0, _rng.randf_range(-4.0, 4.0))
		_place_prop(props, "old_tyre", pos, _rng.randf_range(0.0, 360.0), Vector3(90.0, 0.0, 0.0))
	for i in 6:
		var side: int = 1 if i % 2 == 0 else -1
		var pos: Vector3 = Vector3(_rng.randf_range(-28.0, 28.0), 0.12, side * 7.2)
		_place_prop(props, "wooden_crate_01", pos, _rng.randf_range(-20.0, 20.0), Vector3.ZERO)
	for x: float in [-18.0, -6.0, 15.0, 27.0]:
		var side: int = 1 if x > 0.0 else -1
		_place_prop(
			props, "utility_box_01", Vector3(x, 0.12, side * 7.6), 90.0 * side, Vector3.ZERO
		)


func _place_prop(parent: Node3D, prop: String, pos: Vector3, yaw: float, tilt: Vector3) -> void:
	var scene: PackedScene = load(PROP_PATH % [prop, prop])
	var inst: Node3D = scene.instantiate()
	inst.name = "%s_%d" % [prop, parent.get_child_count()]
	inst.position = pos
	inst.rotation_degrees = Vector3(tilt.x, yaw, tilt.z)
	parent.add_child(inst)
	inst.owner = _root
	var box: AABB = _visual_aabb(inst, Transform3D.IDENTITY)
	if box.size.length() > 0.3:
		_collider(inst.transform * Transform3D(Basis(), box.get_center()), box.size)


func _visual_aabb(node: Node, xform: Transform3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for child: Node in node.get_children():
		if not child is Node3D:
			continue
		var child_xform: Transform3D = xform * (child as Node3D).transform
		var box: AABB = AABB()
		if child is VisualInstance3D:
			box = child_xform * (child as VisualInstance3D).get_aabb()
		var sub: AABB = _visual_aabb(child, child_xform)
		if sub.size != Vector3.ZERO:
			box = sub if box.size == Vector3.ZERO else box.merge(sub)
		if box.size == Vector3.ZERO:
			continue
		result = box if first else result.merge(box)
		first = false
	return result


func _build_markers() -> void:
	var markers: Node3D = Node3D.new()
	markers.name = "Markers"
	_add(markers)
	var start: Marker3D = Marker3D.new()
	start.name = "PlayerStart"
	start.position = Vector3(0.0, 0.2, 2.0)
	markers.add_child(start)
	start.owner = _root
	var i: int = 0
	for x: float in [-28.0, 28.0]:
		for z: float in [-4.0, 0.0, 4.0]:
			var spawn: Marker3D = Marker3D.new()
			spawn.name = "DroidSpawn%d" % i
			spawn.position = Vector3(x, 0.2, z)
			markers.add_child(spawn)
			spawn.owner = _root
			i += 1


func _build_gi() -> void:
	var probe: ReflectionProbe = ReflectionProbe.new()
	probe.name = "StreetProbe"
	probe.position = Vector3(0.0, 6.0, 0.0)
	probe.size = Vector3(STREET_LEN, 20.0, FACADE_Z * 2.0 + 4.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.blend_distance = 2.0
	_add(probe)
	var lightmap: LightmapGI = LightmapGI.new()
	lightmap.name = "LightmapGI"
	lightmap.quality = LightmapGI.BAKE_QUALITY_LOW
	lightmap.bounces = 2
	lightmap.max_texture_size = 4096
	_add(lightmap)


func _flush_static_meshes() -> void:
	var geo: Node3D = Node3D.new()
	geo.name = "Geometry"
	_add(geo)
	for key: String in _tools:
		var entry: Array = _tools[key]
		var mat: Material = _mats[entry[1]]
		var mesh: ArrayMesh = SpikeKit.finish(entry[0], mat)
		var err: Error = mesh.lightmap_unwrap(Transform3D.IDENTITY, LIGHTMAP_TEXEL)
		if err != OK:
			push_warning("lightmap_unwrap failed for %s: %s" % [key, error_string(err)])
		mesh.surface_set_material(0, mat)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = key.to_pascal_case()
		mi.mesh = mesh
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		geo.add_child(mi)
		mi.owner = _root


func _tool(key: String, mat_key: String) -> SurfaceTool:
	if not _tools.has(key):
		_tools[key] = [SpikeKit.begin(), mat_key]
	return _tools[key][0]


func _collider(xform: Transform3D, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.transform = xform
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_collision.add_child(body)
	body.owner = _root
	shape.owner = _root


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _add(node: Node) -> void:
	_root.add_child(node)
	node.owner = _root
