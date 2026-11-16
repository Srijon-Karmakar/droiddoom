extends Node3D
## Dev-only scene for task P0-12. Not part of the game: release presets exclude it.
##
## Finds out which 3D rendering features really work on the current renderer and
## platform. Each check renders the scene with one feature OFF, then ON, and
## compares the two frames. A visible difference means the feature renders.
## Results print with the "[FC]" prefix (terminal or browser console) and show on
## screen at the end.
## Web: `.\tools\web.ps1 -Preset web_featurecheck`
## Desktop: `godot_console --path game <this .tscn path> -- --fc-quit`
## (add `--fc-shot` to save a screenshot of all stations, `--fc-dump` to save every
## OFF/ON frame pair, both to user://).

const PIXEL_DELTA: int = 8
const PASS_FRACTION: float = 0.001
const SAMPLE_STEP: int = 4
const SETTLE_FRAMES: int = 5
const WARMUP_FRAMES: int = 30
const MAIN_EYE: Vector3 = Vector3(0.0, 9.0, 14.0)
const MAIN_TARGET: Vector3 = Vector3(0.0, 0.5, 0.0)
const LIGHTMAP_EYE: Vector3 = Vector3(-200.0, 7.0, 9.0)
const LIGHTMAP_TARGET: Vector3 = Vector3(-200.0, 0.5, -1.0)
const OCCLUSION_ORIGIN: Vector3 = Vector3(300.0, 0.0, 0.0)
const LOAD_TEST_PATH: String = "res://world/common/boot.tscn"
const SCREEN_SHADER: String = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	ALBEDO = vec3(1.0) - textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
}
"""
const DEPTH_SHADER: String = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D depth_tex : hint_depth_texture;
void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	ALBEDO = vec3(fract(-view.z / view.w));
}
"""

var _results: Array[Dictionary] = []
var _info: Dictionary = {}
var _current_check: String = "control"
var _omni: OmniLight3D
var _spot: SpotLight3D
var _probe: ReflectionProbe
var _decal: Decal
var _gpu_particles: GPUParticles3D
var _cpu_particles: CPUParticles3D
var _screen_quad: MeshInstance3D
var _depth_quad: MeshInstance3D

@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _lightmap: LightmapGI = $LightmapArea/LightmapGI
@onready var _label: Label = $HUD/Report


func _ready() -> void:
	_build_stations()
	_build_occlusion_test()
	_camera.look_at_from_position(MAIN_EYE, MAIN_TARGET)
	_collect_info()
	_label.text = "Feature check running..."
	await _settle(WARMUP_FRAMES)
	await _run_checks()
	_finish()


func _run_checks() -> void:
	var vp: Viewport = get_viewport()
	var noise: float = await _measure(func(_on: bool) -> void: pass)
	_info["noise_floor_pct"] = snappedf(noise * 100.0, 0.01)

	await _check(
		"tonemap_agx",
		func(on: bool) -> void:
			_env.tonemap_mode = (
				Environment.TONE_MAPPER_AGX if on else Environment.TONE_MAPPER_LINEAR
			)
	)
	await _check(
		"tonemap_aces",
		func(on: bool) -> void:
			_env.tonemap_mode = (
				Environment.TONE_MAPPER_ACES if on else Environment.TONE_MAPPER_LINEAR
			)
	)
	await _check("glow", func(on: bool) -> void: _env.glow_enabled = on)
	await _check("fog_depth", func(on: bool) -> void: _env.fog_enabled = on)
	await _check(
		"fog_height",
		func(on: bool) -> void:
			_env.fog_enabled = true
			_env.fog_height_density = 0.8 if on else 0.0,
		func() -> void: _env.fog_enabled = false
	)
	await _check("fog_volumetric", func(on: bool) -> void: _env.volumetric_fog_enabled = on)
	await _check("color_adjustments", func(on: bool) -> void: _env.adjustment_enabled = on)
	await _check("ssao", func(on: bool) -> void: _env.ssao_enabled = on)
	await _check("ssil", func(on: bool) -> void: _env.ssil_enabled = on)
	await _check("ssr", func(on: bool) -> void: _env.ssr_enabled = on)
	await _check("sdfgi", func(on: bool) -> void: _env.sdfgi_enabled = on)
	await _check("shadow_directional", func(on: bool) -> void: _sun.shadow_enabled = on)
	await _check("shadow_omni", func(on: bool) -> void: _omni.shadow_enabled = on)
	await _check("shadow_spot", func(on: bool) -> void: _spot.shadow_enabled = on)
	await _check("gpu_particles", func(on: bool) -> void: _gpu_particles.visible = on)
	await _check("cpu_particles", func(on: bool) -> void: _cpu_particles.visible = on)
	await _check("decal", func(on: bool) -> void: _decal.visible = on)
	# UPDATE_ONCE probes need several frames to fill. UPDATE_ALWAYS renders black on
	# Compatibility (4.7.2), so the game must use UPDATE_ONCE.
	await _check(
		"reflection_probe", func(on: bool) -> void: _probe.visible = on, Callable(), WARMUP_FRAMES
	)
	await _check("shader_screen_texture", func(on: bool) -> void: _screen_quad.visible = on)
	await _check("shader_depth_texture", func(on: bool) -> void: _depth_quad.visible = on)
	await _check(
		"msaa_4x",
		func(on: bool) -> void: vp.msaa_3d = Viewport.MSAA_4X if on else Viewport.MSAA_DISABLED
	)
	await _check(
		"fxaa",
		func(on: bool) -> void:
			vp.screen_space_aa = (
				Viewport.SCREEN_SPACE_AA_FXAA if on else Viewport.SCREEN_SPACE_AA_DISABLED
			)
	)
	await _check("taa", func(on: bool) -> void: vp.use_taa = on)
	await _check(
		"render_scale_0.5", func(on: bool) -> void: vp.scaling_3d_scale = 0.5 if on else 1.0
	)
	await _check(
		"fsr1_upscale",
		func(on: bool) -> void:
			vp.scaling_3d_scale = 0.5
			vp.scaling_3d_mode = (
				Viewport.SCALING_3D_MODE_FSR if on else Viewport.SCALING_3D_MODE_BILINEAR
			),
		func() -> void:
			vp.scaling_3d_scale = 1.0
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	)
	await _check_lightmap()
	await _check_occlusion()
	await _check_threaded_loading()


## Renders OFF and ON states of one feature and records whether the frame changed.
func _check(
	check_name: String,
	setter: Callable,
	cleanup: Callable = Callable(),
	frames: int = SETTLE_FRAMES
) -> void:
	_label.text = "Feature check: %s (%d done)" % [check_name, _results.size()]
	_current_check = check_name
	var changed: float = await _measure(setter, frames)
	if cleanup.is_valid():
		cleanup.call()
	_record(
		check_name, "YES" if changed >= PASS_FRACTION else "NO", "%.2f%% px" % (changed * 100.0)
	)


func _measure(setter: Callable, frames: int = SETTLE_FRAMES) -> float:
	setter.call(false)
	await _settle(frames)
	var off_frame: Image = _grab()
	setter.call(true)
	await _settle(frames)
	var on_frame: Image = _grab()
	setter.call(false)
	if OS.get_cmdline_user_args().has("--fc-dump"):
		var prefix: String = "user://fc_%s_%s" % [_info.renderer, _current_check]
		off_frame.save_png(prefix + "_off.png")
		on_frame.save_png(prefix + "_on.png")
	return _changed_fraction(off_frame, on_frame)


func _check_lightmap() -> void:
	var data: LightmapGIData = _lightmap.light_data
	if data == null:
		_record("lightmap_gi", "SKIP", "not baked (bake LightmapArea/LightmapGI in the editor)")
		return
	_camera.look_at_from_position(LIGHTMAP_EYE, LIGHTMAP_TARGET)
	await _check(
		"lightmap_gi",
		func(on: bool) -> void: _lightmap.light_data = data if on else null,
		func() -> void: _lightmap.light_data = data
	)
	_camera.look_at_from_position(MAIN_EYE, MAIN_TARGET)


func _check_occlusion() -> void:
	var sub: SubViewport = SubViewport.new()
	sub.size = Vector2i(640, 360)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var cam: Camera3D = Camera3D.new()
	sub.add_child(cam)
	cam.look_at_from_position(
		OCCLUSION_ORIGIN + Vector3(0.0, 3.0, 12.0), OCCLUSION_ORIGIN + Vector3(0.0, 2.0, 0.0)
	)
	cam.current = true
	sub.use_occlusion_culling = false
	await _settle()
	var drawn_off: int = sub.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME
	)
	sub.use_occlusion_culling = true
	await _settle(SETTLE_FRAMES * 2)
	var drawn_on: int = sub.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME
	)
	sub.queue_free()
	var works: bool = drawn_off > 0 and drawn_on < drawn_off / 2
	_record(
		"occlusion_culling",
		"YES" if works else "NO",
		"objects drawn %d -> %d" % [drawn_off, drawn_on]
	)


func _check_threaded_loading() -> void:
	var start_us: int = Time.get_ticks_usec()
	var err: Error = ResourceLoader.load_threaded_request(
		LOAD_TEST_PATH, "", false, ResourceLoader.CACHE_MODE_IGNORE
	)
	var request_ms: float = (Time.get_ticks_usec() - start_us) / 1000.0
	var frames: int = 0
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		LOAD_TEST_PATH
	)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and frames < 600:
		await get_tree().process_frame
		frames += 1
		status = ResourceLoader.load_threaded_get_status(LOAD_TEST_PATH)
	var loaded: bool = ResourceLoader.load_threaded_get(LOAD_TEST_PATH) != null
	_record(
		"threaded_loading",
		"YES" if err == OK and loaded else "NO",
		(
			"request call %.1f ms, finished after %d frames, threads=%s"
			% [request_ms, frames, OS.has_feature("threads")]
		)
	)


func _record(check_name: String, verdict: String, detail: String) -> void:
	_results.append({"check": check_name, "works": verdict, "detail": detail})
	print("[FC] %-22s %-4s  %s" % [check_name, verdict, detail])


func _finish() -> void:
	print("[FC] INFO ", JSON.stringify(_info))
	print("[FC] JSON ", JSON.stringify({"info": _info, "results": _results}))
	var lines: PackedStringArray = [
		"P0-12 feature check  |  %s  |  %s  |  %s" % [_info.godot, _info.platform, _info.driver],
		(
			"GPU: %s  |  API: %s  |  noise floor %.2f%%"
			% [_info.gpu, _info.api, _info.noise_floor_pct]
		),
		"",
	]
	for r: Dictionary in _results:
		lines.append("%-22s %-4s %s" % [r.check, r.works, r.detail])
	_label.text = "\n".join(lines)
	_show_gallery()
	await _settle(WARMUP_FRAMES)
	if OS.get_cmdline_user_args().has("--fc-shot"):
		var shot: String = "user://feature_check_%s.png" % _info.renderer
		_grab().save_png(shot)
		print("[FC] SHOT ", ProjectSettings.globalize_path(shot))
	print("[FC] DONE")
	if OS.get_cmdline_user_args().has("--fc-quit"):
		get_tree().quit()


## Turns every station on so a screenshot shows them all.
func _show_gallery() -> void:
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.glow_enabled = true
	_sun.shadow_enabled = true
	_omni.shadow_enabled = true
	_spot.shadow_enabled = true
	for node: Node3D in [_gpu_particles, _cpu_particles, _decal, _probe, _screen_quad, _depth_quad]:
		node.visible = true


func _collect_info() -> void:
	_info = {
		"godot": Engine.get_version_info()["string"],
		"platform": OS.get_name(),
		"threads": OS.has_feature("threads"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"viewport": str(get_viewport().get_visible_rect().size),
		"tex_s3tc": RenderingServer.has_os_feature("s3tc"),
		"tex_bptc": RenderingServer.has_os_feature("bptc"),
		"tex_etc2": RenderingServer.has_os_feature("etc2"),
		"tex_astc": RenderingServer.has_os_feature("astc"),
	}


func _settle(frames: int = SETTLE_FRAMES) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw


func _grab() -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _changed_fraction(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	var w: int = a.get_width()
	var changed: int = 0
	var total: int = 0
	for y in range(0, a.get_height(), SAMPLE_STEP):
		var row: int = y * w * 3
		for x in range(0, w, SAMPLE_STEP):
			var i: int = row + x * 3
			total += 1
			if (
				absi(da[i] - db[i]) > PIXEL_DELTA
				or absi(da[i + 1] - db[i + 1]) > PIXEL_DELTA
				or absi(da[i + 2] - db[i + 2]) > PIXEL_DELTA
			):
				changed += 1
	return float(changed) / float(maxi(total, 1))


func _build_stations() -> void:
	var concrete: StandardMaterial3D = _mat(Color(0.45, 0.43, 0.4), 0.0, 0.85)
	var steel: StandardMaterial3D = _mat(Color(0.3, 0.31, 0.33), 0.6, 0.45)
	var mirror: StandardMaterial3D = _mat(Color(0.95, 0.95, 0.95), 1.0, 0.05)
	var glow_mat: StandardMaterial3D = _mat(Color(0.2, 0.9, 1.0), 0.0, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.2, 0.9, 1.0)
	glow_mat.emission_energy_multiplier = 6.0

	var ground: PlaneMesh = PlaneMesh.new()
	ground.size = Vector2(40.0, 40.0)
	ground.material = concrete
	_add_mesh(ground, Vector3.ZERO)
	_add_box(Vector3(30.0, 6.0, 0.4), Vector3(0.0, 3.0, -8.0), concrete)
	_add_box(Vector3.ONE, Vector3(-7.0, 0.5, -3.0), glow_mat)
	_add_box(Vector3(1.0, 3.0, 1.0), Vector3(-3.0, 1.5, -4.0), steel)
	_add_box(Vector3(0.8, 1.6, 0.8), Vector3(5.0, 0.8, 1.0), steel)
	_add_box(Vector3.ONE, Vector3(-5.0, 0.5, 2.0), steel)

	_env.fog_density = 0.03
	_env.fog_height = 3.0
	_env.volumetric_fog_density = 0.05
	_env.adjustment_saturation = 0.3
	_env.adjustment_contrast = 1.3

	_omni = OmniLight3D.new()
	_omni.position = Vector3(6.5, 2.2, 2.5)
	_omni.omni_range = 7.0
	_omni.light_energy = 3.0
	_omni.light_color = Color(1.0, 0.75, 0.5)
	add_child(_omni)

	_spot = SpotLight3D.new()
	_spot.spot_range = 12.0
	_spot.spot_angle = 35.0
	_spot.light_energy = 4.0
	add_child(_spot)
	_spot.look_at_from_position(Vector3(-2.0, 3.5, 5.0), Vector3(-5.0, 0.0, 2.0))

	var sphere: SphereMesh = SphereMesh.new()
	sphere.material = mirror
	_add_mesh(sphere, Vector3(1.5, 1.0, -1.0)).scale = Vector3(2.0, 2.0, 2.0)
	_probe = ReflectionProbe.new()
	_probe.size = Vector3(14.0, 8.0, 14.0)
	_probe.position = Vector3(1.5, 1.0, -1.0)
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.visible = false
	add_child(_probe)

	_decal = Decal.new()
	_decal.size = Vector3(3.0, 2.0, 3.0)
	_decal.position = Vector3(-1.5, 0.0, 4.0)
	_decal.texture_albedo = _circle_texture(Color(0.9, 0.1, 0.1))
	_decal.visible = false
	add_child(_decal)

	_gpu_particles = _make_gpu_particles()
	_gpu_particles.position = Vector3(3.5, 0.3, 4.0)
	_cpu_particles = _make_cpu_particles()
	_cpu_particles.position = Vector3(6.0, 0.3, 4.0)

	_screen_quad = _shader_quad(SCREEN_SHADER, Vector3(-7.0, 1.5, 3.0))
	_depth_quad = _shader_quad(DEPTH_SHADER, Vector3(8.0, 1.5, -2.0))


func _build_occlusion_test() -> void:
	var occluder: OccluderInstance3D = OccluderInstance3D.new()
	var box: BoxOccluder3D = BoxOccluder3D.new()
	box.size = Vector3(14.0, 8.0, 0.5)
	occluder.occluder = box
	occluder.position = OCCLUSION_ORIGIN + Vector3(0.0, 4.0, 0.0)
	add_child(occluder)
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3(0.5, 0.5, 0.5)
	for ix in 10:
		for iz in 10:
			var offset: Vector3 = Vector3(ix - 4.5, 1.0, -2.0 - iz)
			_add_mesh(cube, OCCLUSION_ORIGIN + offset)


func _make_gpu_particles() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 3.5
	process.gravity = Vector3(0.0, -2.0, 0.0)
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = 64
	particles.lifetime = 1.5
	particles.preprocess = 1.5
	particles.process_material = process
	particles.draw_pass_1 = _particle_quad(Color(1.0, 0.6, 0.1))
	particles.visible = false
	add_child(particles)
	return particles


func _make_cpu_particles() -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = 64
	particles.lifetime = 1.5
	particles.preprocess = 1.5
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -2.0, 0.0)
	particles.mesh = _particle_quad(Color(0.4, 1.0, 0.3))
	particles.visible = false
	add_child(particles)
	return particles


func _particle_quad(color: Color) -> QuadMesh:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	quad.material = mat
	return quad


func _shader_quad(code: String, pos: Vector3) -> MeshInstance3D:
	var shader: Shader = Shader.new()
	shader.code = code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = mat
	var inst: MeshInstance3D = _add_mesh(quad, pos)
	inst.visible = false
	return inst


func _circle_texture(color: Color) -> ImageTexture:
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var inside: bool = Vector2(x, y).distance_to(center) < size * 0.45
			img.set_pixel(x, y, color if inside else Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = mat
	return _add_mesh(box, pos)


func _add_mesh(mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
	return inst
