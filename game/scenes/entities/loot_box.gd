class_name LootBox
extends StaticBody3D
## Loot box of a farm zone (spec 004). The first interaction rolls its loot
## table once into its own InventoryComponent (spec 005). Once opened it is a
## container with the capacity of a chest (spec 012, R-012-37): every
## interaction during the visit, also when it is empty, announces `opened`,
## and it is never disabled; what is left in it is lost with the next visit
## (R-012-38). It knows neither the opener's inventory nor the UI. Wiring and
## presentation only: the roll is LootSystem's.

## Once, on the roll (R-004-23); never on restore_opened() (spec 010).
signal loot_generated(stacks: Array[ItemStack], opener: Node3D)
## Every interaction, after the roll on the first one (R-012-37).
signal opened(opener: Node3D)

@export var loot_table: LootTableData
## The same resource as the storage chest's (R-012-06).
@export var container_config: ContainerConfigData

const _CONTENTS_KEY := "contents"

var _loot_seed: int = 0
var _is_set_up: bool = false
var _rolled: bool = false

@onready var _interactable: InteractableComponent = %Interactable
@onready var _closed_mesh: MeshInstance3D = %ClosedMesh
@onready var _opened_mesh: MeshInstance3D = %OpenedMesh
@onready var _contents: InventoryComponent = %Contents


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


## Gives the box the seed of its contents; the zone calls it when it places
## the box. The seed, not the order of opening, decides the loot.
func setup(loot_seed: int) -> void:
	_loot_seed = loot_seed
	_is_set_up = true


func get_contents() -> InventoryComponent:
	return _contents


## Rolled at least once, or restored opened.
func is_opened() -> bool:
	return _rolled


## Null when it was not opened in this visit; else what is left inside, in
## save form (spec 010, R-010-27).
func get_save_state() -> Variant:
	if not _rolled:
		return null
	return {_CONTENTS_KEY: _contents.to_save_data()}


## Opened with the saved contents and the capacity of a chest, without rolling
## and without loot_generated nor opened (R-010-27, D15): loading is not
## opening. A saved list longer than the capacity loses the extra slots,
## reported by InventoryComponent.from_save_data (plan 012 §7). Already opened
## or malformed → push_error, no change.
func restore_opened(saved: Dictionary) -> void:
	var saved_contents: Variant = saved.get(_CONTENTS_KEY)
	var contents: Dictionary = saved_contents if saved_contents is Dictionary else {}
	if _rolled or InventoryComponent.get_saved_slot_count(contents) < 0:
		push_error("LootBox '%s': cannot restore it opened with %s." % [name, saved])
		return
	_rolled = true
	_show_opened()
	_contents.set_slot_count(_capacity())
	_contents.from_save_data(contents)


func _on_interacted(interactor: Node3D) -> void:
	if not _rolled:
		if not _is_set_up:
			push_error("LootBox '%s': opened before setup() gave it a loot seed." % name)
			return
		_roll(interactor)
	opened.emit(interactor)


func _roll(interactor: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _loot_seed
	var stacks: Array[ItemStack] = LootSystem.roll(loot_table, rng)
	_rolled = true
	_show_opened()
	_contents.set_slot_count(_capacity())
	if not _contents.add_stacks(stacks).ok:
		push_error("LootBox '%s': its roll did not fit in its own contents." % name)
	loot_generated.emit(stacks, interactor)


func _capacity() -> int:
	if container_config == null:
		push_error("LootBox '%s': container_config must be assigned." % name)
		return 0
	return container_config.slot_count


func _show_opened() -> void:
	_closed_mesh.visible = false
	_opened_mesh.visible = true
