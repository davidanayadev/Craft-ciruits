extends GutTest
## HitFlashComponent (spec 007): a flash lays its material over the meshes and
## takes it away after the flash time of the feedback data (R-007-24), and
## clear() removes it at once for a pooled entity (R-007-23). Time advances by
## hand through advance(). The duration is a test input, exact in binary.

const FLASH_S := 0.25
const STEP := 0.125

var _flash: HitFlashComponent
var _meshes: Array[GeometryInstance3D] = []
var _material: StandardMaterial3D


func before_each() -> void:
	_meshes = []
	for i: int in 2:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		add_child_autofree(mesh)
		_meshes.append(mesh)
	_material = StandardMaterial3D.new()
	var feedback: CombatFeedbackData = CombatFeedbackData.new()
	feedback.enemy_flash_s = FLASH_S
	_flash = HitFlashComponent.new()
	_flash.name = "HitFlash"
	_flash.meshes = _meshes
	_flash.material = _material
	_flash.feedback = feedback
	add_child_autofree(_flash)


func _every_overlay_is(expected: Material) -> bool:
	for mesh: GeometryInstance3D in _meshes:
		if mesh.material_overlay != expected:
			return false
	return true


func test_r_007_24_idle_at_start() -> void:
	assert_false(_flash.is_flashing(), "no flash before a hit")
	assert_true(_every_overlay_is(null), "the meshes keep their look")
	assert_false(_flash.is_processing(), "and it does not process")


func test_r_007_24_flash_sets_material_on_every_mesh() -> void:
	_flash.flash()
	assert_true(_flash.is_flashing(), "flashing")
	assert_true(_every_overlay_is(_material), "the shared material covers every mesh")
	assert_true(_flash.is_processing(), "it processes while it flashes")


func test_r_007_24_flash_ends_after_its_time() -> void:
	_flash.flash()
	_flash.advance(STEP)
	assert_true(_flash.is_flashing(), "half the time: still white")
	_flash.advance(STEP)
	assert_false(_flash.is_flashing(), "the flash ends at its time")
	assert_true(_every_overlay_is(null), "the material is taken away")
	assert_false(_flash.is_processing(), "and it stops processing")


func test_r_007_24_new_hit_restarts_the_flash() -> void:
	_flash.flash()
	_flash.advance(STEP)
	_flash.flash()
	_flash.advance(STEP)
	assert_true(_flash.is_flashing(), "a second hit starts the time again")


func test_r_007_23_clear_removes_overlay() -> void:
	_flash.flash()
	_flash.clear()
	assert_false(_flash.is_flashing(), "not flashing")
	assert_true(_every_overlay_is(null), "no material left")
	assert_false(_flash.is_processing(), "not processing")


func test_r_007_24_missing_data_reports_error() -> void:
	var broken: HitFlashComponent = HitFlashComponent.new()
	broken.name = "Broken"
	add_child_autofree(broken)
	assert_push_error("Broken")
	broken.flash()
	assert_false(broken.is_flashing(), "without data it never flashes")
