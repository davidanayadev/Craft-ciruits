class_name EnemySpawnEntryData
extends Resource
## One line of a zone's enemy spawns (BALANCE.md §7): a kind of enemy and how
## much of the zone's population it gets.

@export var enemy: EnemyData
## Enemies of this kind placed before the weights decide the rest.
@export var min_count: int = 0
## Relative share of the enemies left after every minimum; 0 gives only the
## minimum.
@export var weight: int = 0
