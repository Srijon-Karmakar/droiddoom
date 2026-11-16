// Environment kit surface with occlusion fade (P1-05, TDD §3.3).
// Pixels inside a cylinder from the camera to the player are dithered away,
// so walls and roofs between them never hide HOLLOW. Works on merged meshes
// (no per-object state), costs a few ALU ops per pixel, no CPU raycasts.
// The CameraRig sets the two global uniforms every frame. Radius 0 = off
// (editor, lightmap bake).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec3 occlusion_target;
global uniform float occlusion_radius;

uniform bool use_textures = true;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness_value = 1.0;
uniform float metallic_value = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// Share of pixels removed at full fade. < 1 leaves a faint screen-door ghost.
uniform float max_fade = 0.85;

varying vec3 world_pos;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0
);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 0 = keep, 1 = fully faded. Only between the camera and the target.
float occlusion_fade(vec3 p, vec3 cam) {
	vec3 to_target = occlusion_target - cam;
	float len = length(to_target);
	if (occlusion_radius <= 0.0 || len < 0.01) {
		return 0.0;
	}
	vec3 dir = to_target / len;
	float t = dot(p - cam, dir);
	float before_target = 1.0 - smoothstep(len - 0.6, len - 0.2, t);
	float d = length(p - (cam + dir * t));
	float radial = 1.0 - smoothstep(occlusion_radius * 0.6, occlusion_radius, d);
	return step(0.0, t) * before_target * radial;
}

void fragment() {
	// Orthographic projection = directional shadow pass: never cut shadows.
	bool shadow_pass = PROJECTION_MATRIX[3][3] == 1.0;
	if (!shadow_pass) {
		float fade = occlusion_fade(world_pos, CAMERA_POSITION_WORLD) * max_fade;
		if (fade > 0.0) {
			ivec2 c = ivec2(FRAGCOORD.xy) % 4;
			if (fade > (BAYER[c.y * 4 + c.x] + 0.5) / 16.0) {
				discard;
			}
		}
	}
	if (use_textures) {
		ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb;
		vec3 orm = texture(orm_tex, UV).rgb;
		ROUGHNESS = orm.g * roughness_value;
		METALLIC = orm.b * metallic_value;
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	} else {
		ALBEDO = tint.rgb;
		ROUGHNESS = roughness_value;
		METALLIC = metallic_value;
	}
	EMISSION = emission_color * emission_energy;
}
