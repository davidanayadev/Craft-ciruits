class_name ItemStack
extends RefCounted
## A quantity of one item (architecture §9.3). Only the fields used so far:
## the inventory (spec 005) and pieces (spec 014) add theirs.

var item: ItemData
var quantity: int


func _init(p_item: ItemData, p_quantity: int) -> void:
	item = p_item
	quantity = p_quantity
