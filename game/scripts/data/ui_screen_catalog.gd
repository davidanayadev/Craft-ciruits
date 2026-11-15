class_name UIScreenCatalog
extends Resource
## Screens UIManager can open, by id (architecture §9.5). Each screen declares
## its own id as a SCREEN_ID constant.

@export var screens: Dictionary[StringName, PackedScene] = {}
