extends Node
## The ONLY place where currencies change (AGENTS.md rule 5).
##
## Stub (P0-04). Full implementation + unit tests come in P2-07.

const SCRAP: StringName = &"scrap"
const SHARDS: StringName = &"shards"
const CORES: StringName = &"cores"


## Returns the current amount of a currency.
func get_amount(currency: StringName) -> int:
	return int(Profile.data["currencies"].get(currency, 0))
