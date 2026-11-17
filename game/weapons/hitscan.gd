class_name Hitscan
extends RefCounted
## Instant-hit ray resolution (D-027). Two rays: one against world bodies,
## one against hurtbox areas on the target factions, limited to where the
## world ray stopped. The nearer hit wins, so walls block shots and movement
## capsules never get in the way of hit shapes.


## Returns {} for a miss, else {"position", "normal", "hurtbox"} where
## "hurtbox" is a HurtboxComponent or null (hit a wall).
static func cast(
	space: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	target_mask: int,
	exclude: Array[RID] = []
) -> Dictionary:
	var world_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, PhysicsLayers.WORLD, exclude
	)
	var world_hit: Dictionary = space.intersect_ray(world_query)
	var end: Vector3 = to if world_hit.is_empty() else world_hit["position"]

	var target_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, end, target_mask, exclude
	)
	target_query.collide_with_areas = true
	target_query.collide_with_bodies = false
	var target_hit: Dictionary = space.intersect_ray(target_query)
	if not target_hit.is_empty():
		var hurtbox: HurtboxComponent = target_hit["collider"] as HurtboxComponent
		if hurtbox != null:
			return {
				"position": target_hit["position"],
				"normal": target_hit["normal"],
				"hurtbox": hurtbox,
			}
	if world_hit.is_empty():
		return {}
	return {"position": world_hit["position"], "normal": world_hit["normal"], "hurtbox": null}
