class_name FakePersistentOwner
extends Node
## A made-up owner of persisted state for the tests of spec 010 (R-010-25): it
## follows the contract of architecture §10.2 and nothing else, so a test can
## show that a new owner in the "persistent" group is saved and loaded with no
## change in SaveManager.

const SAVE_KEY := &"fake_owner"
const _VALUE_KEY := "value"

var value: int = 0


func get_save_key() -> StringName:
	return SAVE_KEY


func to_save_data() -> Dictionary:
	return {_VALUE_KEY: value}


func from_save_data(data: Dictionary) -> void:
	value = SaveFields.to_int(data.get(_VALUE_KEY), value)
