class_name LocalStore
extends IStore
## The store of the MVP (spec 010, TOOLING §3, R-010-59): always the demo.
## Nothing is ever bought, so it needs neither the Profile nor any network;
## native billing replaces it in v1.1.

const ERR_STORE_DEMO := &"ERR_STORE_DEMO"


func has_entitlement(_entitlement_id: StringName) -> bool:
	return false


## Fails with ERR_STORE_DEMO and changes nothing.
func purchase(sku: StringName) -> void:
	purchase_finished.emit.call_deferred(sku, ActionResult.failure(ERR_STORE_DEMO))


## Nothing to restore.
func restore() -> void:
	restore_finished.emit.call_deferred(ActionResult.success())
