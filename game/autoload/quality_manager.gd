extends Node
## Applies graphics quality presets, runs the first-launch benchmark and
## drives dynamic resolution (TDD §6.2).
##
## Stub (P0-04). Presets + dynamic resolution come in P05-05.

enum Preset { LOW, MEDIUM, HIGH, ULTRA }

## Active preset. Web and mobile default to LOW until the benchmark exists.
var preset: Preset = Preset.LOW


func _ready() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		preset = Preset.LOW
	else:
		preset = Preset.MEDIUM


## Returns the GPU name. Used for auto-detection and debug display.
func get_gpu_name() -> String:
	return RenderingServer.get_video_adapter_name()


## Returns the preset name for UI and debug display.
func get_preset_name() -> String:
	return Preset.keys()[preset]
