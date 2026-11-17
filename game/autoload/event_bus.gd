extends Node
## Global signal hub. It holds no state.
##
## Systems emit and listen here instead of referencing each other directly
## (TDD §3.1). Add new signals here, in past tense, with typed arguments.

@warning_ignore_start("unused_signal")

# --- Combat ---
signal enemy_died(enemy: Node, killer: Node)
signal player_damaged(amount: float, damage_type: int)
signal player_died
## A shot was fired (from muzzle to where it ended). FX and audio listen.
signal weapon_fired(from: Vector3, to: Vector3, damage_type: int)
## A shot or blast hit something. `on_target` = it hit a hurtbox, not a wall.
signal hit_landed(position: Vector3, normal: Vector3, damage_type: int, on_target: bool)

# --- Mission flow ---
signal mission_started(mission_id: StringName)
signal mission_completed(mission_id: StringName, stars: int)
signal mission_failed(mission_id: StringName)
signal wave_started(index: int)

# --- Economy / progression ---
signal scrap_collected(amount: int)
signal currency_changed(currency: StringName, new_amount: int)

# --- Settings / system ---
signal camera_mode_changed(mode: int)
signal quality_preset_changed(preset: int)
signal input_device_changed(device: int)

@warning_ignore_restore("unused_signal")
