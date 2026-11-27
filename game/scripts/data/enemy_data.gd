class_name EnemyData
extends Resource
## One kind of enemy (BALANCE.md §3). Later specs add fields as they need them.

## Who the enemy sides with (SPECS.md §28). Only a data field until factions
## get relations (v1.2).
enum Faction { INFECTED, MACHINE, HUMAN }

## snake_case and stable forever: saves and the network only use ids
## (architecture §8). Never rename a published id.
@export var id: StringName
## Translation key of the player-visible name (ENEMY_ZOMBIE_SLOW…).
@export var name_key: StringName
@export var faction: Faction = Faction.INFECTED
@export var hp_max: int = 0
## Battery points a hit takes from the player, 1:1 (BALANCE §3.1).
@export var hit_damage: float = 0.0
## Metres per second.
@export var move_speed: float = 0.0
## Seconds between two hits while the target stays in attack range.
@export var attack_interval: float = 0.0
## XP for the player who deals the final hit (BALANCE §3.1, §6.2).
@export var xp_reward: int = 0
@export var ai: EnemyAiData
## Rolled once when a player kills it (BALANCE §3.1); null drops nothing.
@export var drop_table: LootTableData
## Rolled after drop_table, with the same RNG, when a player kills it (spec
## 016); null drops no piece.
@export var piece_drop: PieceDropData
