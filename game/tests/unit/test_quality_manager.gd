extends GutTest
## QualityManager v0 (P05-05): preset data is valid and dynamic resolution
## steps down under load, steps up after recovery, and respects its limits.

const FRAME: float = 1.0 / 60.0

var _saved_preset: int


func before_each() -> void:
	_saved_preset = QualityManager.preset
	QualityManager.apply_preset(QualityManager.Preset.LOW)


func after_each() -> void:
	QualityManager.apply_preset(_saved_preset)


func test_every_preset_loads_with_sane_values() -> void:
	for path: String in QualityManager.PRESET_PATHS:
		var p: QualityPreset = load(path) as QualityPreset
		assert_not_null(p, path)
		assert_true(p.render_scale_min <= p.render_scale_max, path + " scale range")
		assert_true(p.render_scale_min >= 0.25, path + " scale min")
		assert_true(p.target_fps >= 30.0, path + " target fps")
		assert_true(p.max_live_enemies > 0, path + " enemy cap")


func test_low_preset_matches_tdd_budget() -> void:
	var p: QualityPreset = QualityManager.settings
	assert_eq(p.max_live_enemies, 40)
	assert_eq(p.max_dynamic_lights, 2)
	assert_almost_eq(p.render_scale_min, 0.6, 0.001)


func test_scale_drops_after_sustained_slow_frames() -> void:
	var start: float = QualityManager.render_scale
	_run_frames(30.0, 1.0)
	assert_eq(QualityManager.render_scale, start, "no drop before 2 s")
	_run_frames(30.0, 1.2)
	assert_lt(QualityManager.render_scale, start, "drops after 2 s over budget")


func test_scale_never_goes_below_preset_minimum() -> void:
	_run_frames(40.0, 120.0)
	assert_almost_eq(QualityManager.render_scale, QualityManager.settings.render_scale_min, 0.001)


func test_scale_recovers_only_after_cooldown() -> void:
	_run_frames(30.0, 2.1)
	var dropped: float = QualityManager.render_scale
	_run_frames(10.0, 6.0)
	assert_eq(QualityManager.render_scale, dropped, "no raise inside the cooldown")
	_run_frames(10.0, 15.0)
	assert_gt(QualityManager.render_scale, dropped, "raises after the cooldown")


func test_single_hitch_is_ignored() -> void:
	var start: float = QualityManager.render_scale
	QualityManager.step_dynamic_resolution(900.0, 0.9)
	QualityManager.step_dynamic_resolution(900.0, 0.9)
	QualityManager.step_dynamic_resolution(900.0, 0.9)
	assert_eq(QualityManager.render_scale, start)


func _run_frames(frame_ms: float, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		QualityManager.step_dynamic_resolution(frame_ms, FRAME)
		t += FRAME
