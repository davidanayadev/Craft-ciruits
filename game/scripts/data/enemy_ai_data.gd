class_name EnemyAiData
extends Resource
## AI tuning of a kind of enemy (BALANCE.md §3.1, "IA de zombies"). Shared by
## the enemies that behave alike, so one change tunes them all. Distances in
## metres on the ground plane, pauses in seconds.

## A living player this close is chased.
@export var vision_radius: float = 0.0
## Inside it the enemy stops and hits once per attack interval.
@export var attack_range: float = 0.0
## Patrol points fall this close to the spawn position.
@export var patrol_radius: float = 0.0
## Idle pause between two patrols: uniform in [min, max].
@export var patrol_pause_min: float = 0.0
@export var patrol_pause_max: float = 0.0
## A chased player farther than this is given up.
@export var give_up_distance: float = 0.0
