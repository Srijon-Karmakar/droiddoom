extends Node
## Persistent player data: currencies, unlocks, upgrades, stars, liberation.
##
## Stub (P0-04). The real schema and migrations come in P2-08.
## Every schema change MUST bump SCHEMA_VERSION and add a migration + test.

const SCHEMA_VERSION: int = 1

## Raw profile data. Only Economy may change currency values.
var data: Dictionary = _default_data()


## Resets the profile to a fresh new-game state.
func reset() -> void:
	data = _default_data()


func _default_data() -> Dictionary:
	return {
		"currencies": {"scrap": 0, "shards": 0, "cores": 0},
		"unlocks": [],
		"stars": {},
		"liberated_sectors": [],
	}
