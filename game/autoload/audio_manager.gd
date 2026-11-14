extends Node
## Music layers, pooled SFX players and volume buses (Master, Music, SFX, Voice, UI).
##
## Stub (P0-04). Implementation comes in P2-14.


## Sets a bus volume from a linear 0..1 value. Does nothing if the bus doesn't exist yet.
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
