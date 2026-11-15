class_name WorldGridConfigData
extends Resource
## Global zone grid (BALANCE.md §7, SPECS.md §26). Every zone fits in one cell.

## Must not change once saved worlds exist: positions are stored per cell.
@export var cell_size_m: float = 0.0
