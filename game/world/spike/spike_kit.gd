class_name SpikeKit
extends RefCounted
## Phase 0.5 spike helpers: PBR materials and merged box geometry.
##
## Boxes are appended to one SurfaceTool so a whole building facade becomes a
## single mesh (one draw call). UVs are in world meters divided by a tile size,
## so textures tile seamlessly across merged boxes.
## TEST CODE for the web 3D feasibility gate (P05-01). Not production.

const PBR_DIR: String = "res://assets/textures/pbr/%s/%s_%s_1k.jpg"

## Face table: normal, right (u) and up (v) as seen from outside. u × v = normal,
## so the quads come out clockwise (Godot front faces).
const FACES: Array[Array] = [
	[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
]


## Builds an ORM PBR material from a Poly Haven texture set (diff / nor_gl / arm).
static func pbr_material(texture_name: String) -> ORMMaterial3D:
	var mat: ORMMaterial3D = ORMMaterial3D.new()
	mat.resource_name = texture_name
	mat.albedo_texture = load(PBR_DIR % [texture_name, texture_name, "diff"])
	mat.orm_texture = load(PBR_DIR % [texture_name, texture_name, "arm"])
	mat.normal_enabled = true
	mat.normal_texture = load(PBR_DIR % [texture_name, texture_name, "nor_gl"])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Same PBR set with an albedo tint (e.g. darker steel for AXIOM droids).
static func tinted_material(texture_name: String, tint: Color) -> ORMMaterial3D:
	var mat: ORMMaterial3D = pbr_material(texture_name)
	mat.albedo_color = tint
	return mat


## Unshaded-looking emissive material (AXIOM red, human cyan...). Feeds glow.
static func emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## Appends a box to `st`. `xform` places the box (rotation + center).
## `tile` is the texture repeat size in meters.
static func add_box(st: SurfaceTool, xform: Transform3D, size: Vector3, tile: float) -> void:
	var half: Vector3 = size * 0.5
	for face: Array in FACES:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var hn: float = absf(half.dot(n))
		var hu: float = absf(half.dot(u))
		var hv: float = absf(half.dot(v))
		var corners: Array[Vector3] = [
			n * hn - u * hu - v * hv,
			n * hn - u * hu + v * hv,
			n * hn + u * hu + v * hv,
			n * hn + u * hu - v * hv,
		]
		var world_n: Vector3 = (xform.basis * n).normalized()
		for i: int in [0, 1, 2, 0, 2, 3]:
			var local: Vector3 = corners[i]
			var world: Vector3 = xform * local
			# Metric UVs from the box's own frame + its center, so rotated rubble still tiles.
			var anchor: Vector3 = local + xform.origin
			st.set_normal(world_n)
			st.set_uv(Vector2(anchor.dot(u), -anchor.dot(v)) / tile)
			st.add_vertex(world)


## Starts a SurfaceTool for triangles.
static func begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Finishes a SurfaceTool into a mesh with tangents and one material.
static func finish(st: SurfaceTool, mat: Material) -> ArrayMesh:
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh
