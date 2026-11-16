class_name PlayerStats
extends Resource
## HOLLOW's base movement and survival stats (P1-02). Upgrades modify a copy at
## mission start. Data lives in `data/player/*.tres`.

## Top run speed (m/s).
@export var move_speed: float = 6.0
## Speed gained per second while moving (m/s²).
@export var acceleration: float = 40.0
## Speed lost per second with no input (m/s²).
@export var friction: float = 30.0
## Downward acceleration (m/s²).
@export var gravity: float = 20.0
## Turret (upper body) turn rate toward the aim (rad/s).
@export var turret_turn_speed: float = 14.0
## Legs turn rate toward the move direction (rad/s).
@export var leg_turn_speed: float = 10.0
## Maximum hit points.
@export var max_hp: float = 100.0
