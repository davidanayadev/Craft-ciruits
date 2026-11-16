class_name CombatFeedbackData
extends Resource
## How combat feels (BALANCE.md §11, "Combate"): flashes in seconds, camera
## shakes as a strength in metres and a duration in seconds.

## White flash of an enemy hit by the robot.
@export var enemy_flash_s: float = 0.0
@export var hit_dealt_shake_m: float = 0.0
@export var hit_dealt_shake_s: float = 0.0
@export var hit_received_shake_m: float = 0.0
@export var hit_received_shake_s: float = 0.0
## Red flash at the screen edges when the robot is hit.
@export var screen_edge_flash_s: float = 0.0
