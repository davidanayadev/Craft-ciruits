class_name LootBox
extends StaticBody3D
## Loot box of a farm zone (spec 004). Interacting with it while closed rolls
## its loot table once and announces the result; it does not know who receives
## it (spec 005 connects the opener's inventory). Wiring and presentation
## only: the roll is LootSystem's.

signal loot_generated(stacks: Array[ItemStack], opener: Node3D)

@export var loot_table: LootTableData

var _loot_seed: int = 0
var _is_set_up: bool = false
var _opened: bool = false

@onready var _interactable: InteractableComponent = %Interactable
@onready var _closed_mesh: MeshInstance3D = %ClosedMesh
@onready var _opened_mesh: MeshInstance3D = %OpenedMesh


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


## Gives the box the seed of its contents; the zone calls it when it places
## the box. The seed, not the order of opening, decides the loot.
func setup(loot_seed: int) -> void:
	_loot_seed = loot_seed
	_is_set_up = true


func is_opened() -> bool:
	return _opened


func _on_interacted(interactor: Node3D) -> void:
	if _opened:
		return
	if not _is_set_up:
		push_error("LootBox '%s': opened before setup() gave it a loot seed." % name)
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _loot_seed
	var stacks: Array[ItemStack] = LootSystem.roll(loot_table, rng)
	_opened = true
	_interactable.enabled = false
	_closed_mesh.visible = false
	_opened_mesh.visible = true
	loot_generated.emit(stacks, interactor)
