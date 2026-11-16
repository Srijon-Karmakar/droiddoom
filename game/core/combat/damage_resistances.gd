class_name DamageResistances
extends Resource
## Damage taken multiplier per damage type. 1.0 = normal, < 1 resists,
## > 1 weak, 0 = immune. Enemy data (P1-08) and Hardened variants (AXIOM
## Adapts) reference these resources.

@export_range(0.0, 3.0, 0.05) var kinetic: float = 1.0
@export_range(0.0, 3.0, 0.05) var energy: float = 1.0
@export_range(0.0, 3.0, 0.05) var emp: float = 1.0


## Multiplier for one damage type.
func multiplier(type: DamageInfo.Type) -> float:
	match type:
		DamageInfo.Type.KINETIC:
			return kinetic
		DamageInfo.Type.ENERGY:
			return energy
		DamageInfo.Type.EMP:
			return emp
	return 1.0
