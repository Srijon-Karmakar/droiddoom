class_name PhysicsLayers
extends RefCounted
## Collision layer bit masks (TDD §3.6). Fixed: never renumber.

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const PLAYER_PROJECTILES: int = 1 << 2
const ENEMIES: int = 1 << 3
const ENEMY_PROJECTILES: int = 1 << 4
const PICKUPS: int = 1 << 5
const ALLIES: int = 1 << 6
const TRIGGERS: int = 1 << 7
const CAMERA_OCCLUDERS: int = 1 << 8
const NAVIGATION_ONLY: int = 1 << 9
