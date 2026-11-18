class_name ActionResult
extends RefCounted
## Result of an action that can fail (architecture §9.2): the one result type
## of the whole game. The UI shows tr(error_key).

## A request that is malformed or names something unknown. Here, in the data
## layer, so pure systems can return it without knowing any node (spec 011).
const ERR_INVALID_REQUEST := &"ERR_INVALID_REQUEST"

var ok: bool = false
## Translation key of the failure; empty when ok.
var error_key: StringName = &""


static func success() -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.ok = true
	return result


static func failure(key: StringName) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.error_key = key
	return result
