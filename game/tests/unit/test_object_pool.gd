extends GutTest
## ObjectPool (spec 006, R-006-22): hands out instances of one scene outside
## the tree, takes them back and reuses them instead of creating and freeing,
## rejects what is not its own or is already free, and frees what it stores
## when it is freed itself.

var _pool: ObjectPool


func before_each() -> void:
	_pool = _new_pool()


func _new_scene() -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "Pooled"
	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(root)
	root.free()
	assert_eq(error, OK, "the test scene packs")
	return scene


func _new_pool() -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.name = "Pool"
	pool.scene = _new_scene()
	add_child_autofree(pool)
	return pool


func test_r_006_22_acquire_creates_outside_the_tree() -> void:
	var instance: Node = _pool.acquire()
	assert_not_null(instance, "an empty pool creates an instance")
	if instance == null:
		return
	assert_true(instance is Node3D, "it is an instance of the pool's scene")
	assert_false(instance.is_inside_tree(), "the caller decides where it goes")
	assert_null(instance.get_parent(), "it has no parent yet")
	_pool.release(instance)


func test_r_006_22_release_takes_it_out_of_the_tree() -> void:
	var holder: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var instance: Node = _pool.acquire()
	holder.add_child(instance)
	_pool.release(instance)
	assert_false(instance.is_inside_tree(), "a released instance leaves the tree")
	assert_eq(holder.get_child_count(), 0, "its parent no longer has it")
	assert_eq(_pool.get_free_count(), 1, "the pool stores it")


func test_r_006_22_reuses_released_instance() -> void:
	var first: Node = _pool.acquire()
	_pool.release(first)
	var second: Node = _pool.acquire()
	assert_same(second, first, "the released instance comes back")
	assert_eq(_pool.get_free_count(), 0, "nothing left in the pool")
	_pool.release(second)


func test_r_006_22_creates_another_when_empty() -> void:
	var first: Node = _pool.acquire()
	var second: Node = _pool.acquire()
	assert_not_null(second, "an empty pool still gives an instance")
	assert_not_same(second, first, "two instances in use are different")
	_pool.release(first)
	_pool.release(second)
	assert_eq(_pool.get_free_count(), 2, "both are stored")


func test_r_006_22_prewarm_fills_the_pool() -> void:
	_pool.prewarm(3)
	assert_eq(_pool.get_free_count(), 3, "three instances ready")
	_pool.prewarm(2)
	assert_eq(_pool.get_free_count(), 3, "prewarm never shrinks nor adds on top")
	var prewarmed: Node = _pool.acquire()
	assert_eq(_pool.get_free_count(), 2, "acquire takes a prewarmed instance")
	_pool.release(prewarmed)


func test_r_006_22_release_foreign_reports_error() -> void:
	var stranger: Node = autofree(Node.new()) as Node
	_pool.release(stranger)
	assert_push_error("Pool")
	assert_eq(_pool.get_free_count(), 0, "a foreign node is not stored")
	_pool.release(null)
	assert_push_error("Pool")


func test_r_006_22_release_twice_reports_error() -> void:
	var instance: Node = _pool.acquire()
	_pool.release(instance)
	_pool.release(instance)
	assert_push_error("Pool")
	assert_eq(_pool.get_free_count(), 1, "stored only once")


func test_r_006_22_missing_scene_reports_error() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.name = "Sceneless"
	add_child_autofree(pool)
	assert_null(pool.acquire(), "no scene, no instance")
	assert_push_error("Sceneless")


func test_r_006_22_frees_stored_instances_on_exit() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = _new_scene()
	add_child(pool)
	pool.prewarm(2)
	var used: Node = pool.acquire()
	var stored: Node = pool.acquire()
	pool.release(stored)
	var stored_id: int = stored.get_instance_id()
	pool.free()
	assert_false(is_instance_id_valid(stored_id), "stored instances are freed with the pool")
	assert_true(is_instance_valid(used), "an instance in use belongs to whoever holds it")
	used.free()
	assert_no_new_orphans("the pool leaves no orphans behind")
