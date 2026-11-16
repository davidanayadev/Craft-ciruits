class_name CombatConfigData
extends Resource
## Shape and timing of a melee swing (BALANCE.md §11, "Combate"). Shared by
## every arm: the arms change the damage and the rate, not the reach.

## Depth of the hitbox, from the attacker's centre forwards.
@export var hitbox_reach_m: float = 0.0
@export var hitbox_width_m: float = 0.0
## Seconds from the start of the swing to its impact. Shorter than the swing
## interval of every attack (guarded by a test).
@export var impact_time_s: float = 0.0
