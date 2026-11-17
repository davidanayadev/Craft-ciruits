class_name LootBox
extends StaticBody3D
## Loot box of a farm zone (spec 004). The first interaction rolls its loot
## table once into its own InventoryComponent; every interaction while it
## still holds items announces `opened`, and the box is disabled for the rest
## of the visit once it is empty (spec 005). It knows neither the opener's
## inventory nor the UI. Wiring and presentation only: the roll is LootSystem's.

## Once, on the roll (R-004-23); never on restore_opened() (spec 010).
signal loot_generated(stacks: Array[ItemStack], opener: Node3D)
## Every interaction while the box still holds items, after the roll on the first one.
signal opened(opener: Node3D)

@export var loot_table: LootTableData

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


## Opened with the saved contents, without rolling and without loot_generated
## nor opened (R-010-27, D15): loading is not opening. Disabled at once if
## empty, as after a roll. Already opened or malformed → push_error, no change.
func restore_opened(saved: Dictionary) -> void:
	var saved_contents: Variant = saved.get(_CONTENTS_KEY)
	var contents: Dictionary = saved_contents if saved_contents is Dictionary else {}
	var slot_count: int = InventoryComponent.get_saved_slot_count(contents)
	if _rolled or slot_count < 0:
		push_error("LootBox '%s': cannot restore it opened with %s." % [name, saved])
		return
	_rolled = true
	_show_opened()
	_contents.set_slot_count(slot_count)
	_contents.from_save_data(contents)
	_watch_contents()


func _on_interacted(interactor: Node3D) -> void:
	if not _rolled:
		if not _is_set_up:
			push_error("LootBox '%s': opened before setup() gave it a loot seed." % name)
			return
		_roll(interactor)
	if not _contents.is_empty():
		opened.emit(interactor)


func _roll(interactor: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _loot_seed
	var stacks: Array[ItemStack] = LootSystem.roll(loot_table, rng)
	_rolled = true
	_show_opened()
	_fill_contents(stacks)
	loot_generated.emit(stacks, interactor)


## One slot per rolled stack: no loot entry rolls more than a slot holds.
func _fill_contents(stacks: Array[ItemStack]) -> void:
	_contents.set_slot_count(stacks.size())
	if not _contents.add_stacks(stacks).ok:
		push_error("LootBox '%s': its roll did not fit in its own contents." % name)
	_watch_contents()


func _show_opened() -> void:
	_closed_mesh.visible = false
	_opened_mesh.visible = true


## Connected only once filled: the changes of the filling itself would arrive
## with the box still empty and disable it for good.
func _watch_contents() -> void:
	_contents.inventory_changed.connect(_on_contents_changed)
	_on_contents_changed()


func _on_contents_changed() -> void:
	if _contents.is_empty():
		_interactable.enabled = false
