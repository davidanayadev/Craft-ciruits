extends GutTest
## InteractableComponent (spec 004, architecture §9.1): the thing an object
## adds to be interactable. It emits interacted only while enabled (R-004-15)
## and sits alone on the "interaction" physics layer, detectable but detecting
## nothing.

var _interactable: InteractableComponent
var _interactor: Node3D


func before_each() -> void:
	_interactable = InteractableComponent.new()
	add_child_autofree(_interactable)
	_interactor = Node3D.new()
	add_child_autofree(_interactor)
	watch_signals(_interactable)


func test_r_004_15_enabled_emits_with_interactor() -> void:
	_interactable.interact(_interactor)
	assert_signal_emit_count(_interactable, "interacted", 1)
	assert_signal_emitted_with_parameters(_interactable, "interacted", [_interactor])


func test_r_004_15_disabled_does_not_emit() -> void:
	_interactable.enabled = false
	_interactable.interact(_interactor)
	assert_signal_not_emitted(_interactable, "interacted")


func test_r_004_15_enabled_again_emits() -> void:
	_interactable.enabled = false
	_interactable.enabled = true
	_interactable.interact(_interactor)
	assert_signal_emit_count(_interactable, "interacted", 1)


func test_r_004_12_only_on_interaction_layer() -> void:
	var layer_bit: int = 1 << (InteractableComponent.PHYSICS_LAYER - 1)
	assert_eq(_interactable.collision_layer, layer_bit, "only on the interaction layer")
	assert_eq(_interactable.collision_mask, 0, "detects nothing")
	assert_false(_interactable.monitoring, "does not monitor")
	assert_true(_interactable.monitorable, "can be detected")
