extends GutTest
## IStore (spec 010): base-class contract of the store, never talks to anything
## (R-010-58). The result signals purchase_finished and restore_finished carry
## an ActionResult; the base methods only report that they are not implemented.

const SKU := &"sku_test"


func _signal_info(store: IStore, signal_name: String) -> Dictionary:
	for info: Dictionary in store.get_signal_list():
		if info["name"] == signal_name:
			return info
	return {}


func _assert_arg(info: Dictionary, index: int, want_name: String, want_type: int, want_class: String) -> void:
	var args: Array = info["args"]
	var arg: Dictionary = args[index]
	var arg_name: String = arg["name"]
	var arg_type: int = arg["type"]
	var arg_class: String = arg["class_name"]
	assert_eq(arg_name, want_name, "argument %d name" % index)
	assert_eq(arg_type, want_type, "argument %d type" % index)
	assert_eq(arg_class, want_class, "argument %d class" % index)


func test_r_010_58_signals() -> void:
	var store: IStore = IStore.new()
	var purchase: Dictionary = _signal_info(store, "purchase_finished")
	assert_false(purchase.is_empty(), "purchase_finished declared")
	if not purchase.is_empty():
		var purchase_args: Array = purchase["args"]
		assert_eq(purchase_args.size(), 2, "purchase_finished: two arguments")
		if purchase_args.size() == 2:
			_assert_arg(purchase, 0, "sku", TYPE_STRING_NAME, "")
			_assert_arg(purchase, 1, "result", TYPE_OBJECT, "ActionResult")
	var restore: Dictionary = _signal_info(store, "restore_finished")
	assert_false(restore.is_empty(), "restore_finished declared")
	if not restore.is_empty():
		var restore_args: Array = restore["args"]
		assert_eq(restore_args.size(), 1, "restore_finished: one argument")
		if restore_args.size() == 1:
			_assert_arg(restore, 0, "result", TYPE_OBJECT, "ActionResult")


func test_r_010_58_base_methods_report_errors() -> void:
	var store: IStore = IStore.new()
	watch_signals(store)
	var entitled: bool = store.has_entitlement(&"any")
	assert_false(entitled, "the base class grants nothing")
	assert_push_error_count(1)
	store.purchase(SKU)
	assert_push_error_count(2)
	store.restore()
	assert_push_error_count(3)
	assert_signal_not_emitted(store, "purchase_finished", "base purchase emits nothing")
	assert_signal_not_emitted(store, "restore_finished", "base restore emits nothing")
