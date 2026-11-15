class_name LootEntryData
extends Resource
## One line of a loot table: an item and its quantity range (BALANCE.md §2.1).

@export var item: ItemData
## Both ends are included; a roll of 0 delivers nothing.
@export var min_quantity: int = 0
@export var max_quantity: int = 0
