class_name KitMaterials
extends RefCounted
## Builds environment kit materials on the occlusion-fade shader (P1-05).
## Use these for anything that can stand between the camera and the player
## (walls, shutters, barricades, poles, roofs). Ground surfaces can keep plain
## materials: they never block the view.

const SHADER: Shader = preload("res://world/kits/common/kit_fade.gdshader")
const PBR_DIR: String = "res://assets/textures/pbr/%s/%s_%s_1k.jpg"


## PBR material from a Poly Haven texture set (diff / nor_gl / arm), tinted.
static func pbr(texture_name: String, tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat: ShaderMaterial = _new(texture_name)
	mat.set_shader_parameter(&"albedo_tex", load(PBR_DIR % [texture_name, texture_name, "diff"]))
	mat.set_shader_parameter(&"orm_tex", load(PBR_DIR % [texture_name, texture_name, "arm"]))
	mat.set_shader_parameter(&"normal_tex", load(PBR_DIR % [texture_name, texture_name, "nor_gl"]))
	mat.set_shader_parameter(&"tint", tint)
	return mat


## Untextured material (glass, painted metal).
static func plain(
	name: String, color: Color, roughness: float, metallic: float = 0.0
) -> ShaderMaterial:
	var mat: ShaderMaterial = _new(name)
	mat.set_shader_parameter(&"use_textures", false)
	mat.set_shader_parameter(&"tint", color)
	mat.set_shader_parameter(&"roughness_value", roughness)
	mat.set_shader_parameter(&"metallic_value", metallic)
	return mat


## Emissive strip (AXIOM red, human cyan). Feeds glow. Fades with its wall.
static func emissive(name: String, color: Color, energy: float) -> ShaderMaterial:
	var mat: ShaderMaterial = plain(name, color.darkened(0.6), 0.5)
	mat.set_shader_parameter(&"emission_color", color)
	mat.set_shader_parameter(&"emission_energy", energy)
	return mat


static func _new(name: String) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.resource_name = name
	mat.shader = SHADER
	return mat
