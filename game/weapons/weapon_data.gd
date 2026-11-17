class_name WeaponData
extends Resource
## Balance data for one weapon (TDD §3.4). Lives in `data/weapons/*.tres`.
## Upgrades (Phase 2) modify a runtime copy, never the file.

## Translation key for the weapon name.
@export var name_key: String = ""
@export var damage: float = 10.0
@export var damage_type: DamageInfo.Type = DamageInfo.Type.KINETIC
## Seconds between shots.
@export var fire_interval: float = 0.12
## Maximum hitscan distance (m).
@export var max_range: float = 60.0
## Random cone half-angle (degrees).
@export var spread_deg: float = 1.5
## 0..1 chance that a shot crits.
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.05
@export var crit_multiplier: float = 2.0
## Push given to the target along the shot (m/s).
@export var knockback: float = 0.0
