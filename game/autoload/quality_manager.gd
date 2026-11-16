extends Node
## Applies graphics quality presets and drives dynamic resolution (TDD §6.2).
##
## v0 (P05-05): presets come from `data/quality/*.tres`. Web and mobile start on
## LOW, desktop on MEDIUM. The first-launch benchmark comes later. On web the GPU
## name is hidden, so it will use frame time only (D-022).
## Dynamic resolution: frames over budget for OVER_BUDGET_SECONDS → render scale
## goes down one step. Frames within budget for UNDER_BUDGET_SECONDS → one step
## up, but not within RAISE_COOLDOWN seconds of a drop (stops oscillation with vsync).

enum Preset { LOW, MEDIUM, HIGH, ULTRA }

const PRESET_PATHS: Array[String] = [
	"res://data/quality/quality_low.tres",
	"res://data/quality/quality_medium.tres",
	"res://data/quality/quality_high.tres",
	"res://data/quality/quality_ultra.tres",
]
const SCALE_STEP: float = 0.05
const OVER_BUDGET_SECONDS: float = 2.0
const UNDER_BUDGET_SECONDS: float = 5.0
const RAISE_COOLDOWN: float = 15.0
const OVER_BUDGET_FACTOR: float = 1.1
## Frames longer than this are hitches (loading, shader compiles), not load. Ignored.
const HITCH_MS: float = 250.0

## Active preset.
var preset: Preset = Preset.LOW
## Data of the active preset.
var settings: QualityPreset
## Dynamic resolution on/off (players can turn it off in Settings later).
var dynamic_resolution: bool = true
## Current 3D render scale chosen by dynamic resolution.
var render_scale: float = 1.0

var _over_time: float = 0.0
var _under_time: float = 0.0
var _since_drop: float = RAISE_COOLDOWN


func _ready() -> void:
	var start: Preset = Preset.MEDIUM
	if OS.has_feature("web") or OS.has_feature("mobile"):
		start = Preset.LOW
	apply_preset(start)


func _process(delta: float) -> void:
	if not dynamic_resolution or settings == null:
		return
	var new_scale: float = step_dynamic_resolution(delta * 1000.0, delta)
	if not is_equal_approx(new_scale, get_viewport().scaling_3d_scale):
		get_viewport().scaling_3d_scale = new_scale


## Loads and applies a preset to the root viewport and the rendering server.
func apply_preset(new_preset: Preset) -> void:
	preset = new_preset
	settings = load(PRESET_PATHS[new_preset]) as QualityPreset
	render_scale = settings.render_scale_max
	_over_time = 0.0
	_under_time = 0.0
	_since_drop = RAISE_COOLDOWN
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.msaa_3d = settings.msaa_3d
		vp.scaling_3d_scale = render_scale
		vp.positional_shadow_atlas_size = settings.positional_shadow_size
	RenderingServer.directional_shadow_atlas_set_size(settings.directional_shadow_size, true)
	EventBus.quality_preset_changed.emit(new_preset)


## Switches to the next preset (wraps around). Dev and settings UI helper.
func cycle_preset() -> void:
	apply_preset(((preset + 1) % Preset.size()) as Preset)


## Advances the dynamic-resolution controller by one frame and returns the
## render scale to use. Pure logic (no engine calls), so it's unit-tested.
func step_dynamic_resolution(frame_ms: float, delta: float) -> float:
	if frame_ms > HITCH_MS:
		return render_scale
	var budget_ms: float = 1000.0 / settings.target_fps
	_since_drop += delta
	if frame_ms > budget_ms * OVER_BUDGET_FACTOR:
		_over_time += delta
		_under_time = 0.0
	else:
		_under_time += delta
		_over_time = 0.0
	if _over_time >= OVER_BUDGET_SECONDS and render_scale > settings.render_scale_min:
		render_scale = maxf(settings.render_scale_min, render_scale - SCALE_STEP)
		_over_time = 0.0
		_since_drop = 0.0
	elif (
		_under_time >= UNDER_BUDGET_SECONDS
		and _since_drop >= RAISE_COOLDOWN
		and render_scale < settings.render_scale_max
	):
		render_scale = minf(settings.render_scale_max, render_scale + SCALE_STEP)
		_under_time = 0.0
	return render_scale


## Returns the GPU name. Hidden on web ("WebKit WebGL"), so don't rely on it there.
func get_gpu_name() -> String:
	return RenderingServer.get_video_adapter_name()


## Returns the preset name for UI and debug display.
func get_preset_name() -> String:
	return settings.display_name if settings != null else Preset.keys()[preset]
