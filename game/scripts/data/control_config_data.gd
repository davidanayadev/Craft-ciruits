class_name ControlConfigData
extends Resource
## Control feel numbers (BALANCE.md §11). Player-tunable options start from
## these values and are stored apart in user://settings.cfg (architecture §10.2).

## Below this fraction of the joystick radius there is no movement (R-002-15).
@export var joystick_dead_zone_ratio: float = 0.0
## Pushing beyond this fraction activates running (R-002-16).
@export var joystick_run_ratio: float = 0.0
## Running releases only below this fraction, to avoid flickering at the edge.
@export var joystick_walk_back_ratio: float = 0.0
## Yaw speed of the smooth turn toward the movement direction (R-002-07).
@export var turn_speed_rad: float = 0.0
## Distance at which the nearest interactable is offered (R-004-17).
@export var interaction_range_m: float = 0.0
## Seconds the slots that received a move stay highlighted (R-013-19).
@export var move_highlight_s: float = 0.0
