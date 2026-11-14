extends Node
## Saves and loads Profile to user:// as JSON with schema_version, checksum,
## atomic write and step-by-step migrations (TDD §3.5).
##
## Stub (P0-04). Implementation comes in P2-08.

const SAVE_PATH: String = "user://profile.json"


## Returns true if a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
