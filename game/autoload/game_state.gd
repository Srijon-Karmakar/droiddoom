extends Node
## State of the current run/session: selected mission, loadout, in-mission stats.
##
## Stub (P0-04). Cleared between missions.

## Mission currently being played (empty when in Haven/menus).
var current_mission_id: StringName = &""
## Kills in the current mission.
var kills: int = 0
## Scrap picked up in the current mission (not yet banked).
var scrap_collected: int = 0


## Clears all per-mission state.
func reset_run() -> void:
	current_mission_id = &""
	kills = 0
	scrap_collected = 0
