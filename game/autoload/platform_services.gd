extends Node
## Facade over platform SDKs: ads, store/IAP, achievements, leaderboards,
## cloud save and analytics (TDD §3.3).
##
## ONLY code under res://platform/ may call SDKs (AGENTS.md rule 4).
## Stub (P0-04). Providers come in Phase 4/5.


## Returns a short id for the current platform: steam, web, android, ios, desktop.
func get_platform_id() -> StringName:
	if OS.has_feature("steam"):
		return &"steam"
	if OS.has_feature("web"):
		return &"web"
	if OS.has_feature("android"):
		return &"android"
	if OS.has_feature("ios"):
		return &"ios"
	return &"desktop"
