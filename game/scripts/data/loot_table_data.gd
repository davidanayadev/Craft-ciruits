class_name LootTableData
extends Resource
## What a container or an enemy can give (BALANCE.md §2.1). Rolled by LootSystem.

## Rolled in this order: reordering changes the loot of saved worlds.
@export var entries: Array[LootEntryData] = []
