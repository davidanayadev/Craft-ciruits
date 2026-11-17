class_name IStore
extends RefCounted
## Contract of the store (spec 010, PMV §4.5 hook 8, R-010-58): the game asks
## it for entitlements and never knows which store answers. Entitlements are
## read from the Profile only (R-010-60). Results of purchase() and restore()
## arrive through the signals, never during the call. GDScript has no
## interfaces: every method push_errors when not overridden.

signal purchase_finished(sku: StringName, result: ActionResult)
signal restore_finished(result: ActionResult)


## Synchronous.
func has_entitlement(_entitlement_id: StringName) -> bool:
	_not_implemented("has_entitlement")
	return false


func purchase(_sku: StringName) -> void:
	_not_implemented("purchase")


func restore() -> void:
	_not_implemented("restore")


func _not_implemented(method: String) -> void:
	push_error("IStore: %s() is not implemented." % method)
