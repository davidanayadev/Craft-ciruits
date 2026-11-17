class_name ItemStack
extends RefCounted
## A quantity of one item (architecture §9.3). Only the fields used so far:
## the inventory (spec 005), the save (spec 010); pieces (spec 014) add theirs.
## The rules that keep durability and uid when stacking are spec 014's.

var item: ItemData
var quantity: int
## Uses left of a piece; -1 when it does not apply (spec 010 saves it).
var durability: int = -1
## Identity of a unique item (architecture §10.3); empty for plain stacks.
var uid: String = ""


func _init(p_item: ItemData, p_quantity: int) -> void:
	item = p_item
	quantity = p_quantity


## Same item, quantity, durability and uid; never shares state with the original.
func copy() -> ItemStack:
	var other: ItemStack = ItemStack.new(item, quantity)
	other.durability = durability
	other.uid = uid
	return other
