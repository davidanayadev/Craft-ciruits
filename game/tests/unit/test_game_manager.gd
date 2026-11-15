extends GutTest
## GameManager holds the world seed of the current game (spec 004, R-004-08).
## Until worlds are saved (spec 010) it is the fixed development seed.

const DEV_WORLD_PATH := "res://resources/config/dev_world.tres"


func test_r_004_08_world_seed_from_dev_world() -> void:
	var dev_world: DevWorldConfigData = load(DEV_WORLD_PATH) as DevWorldConfigData
	assert_not_null(dev_world, "dev_world.tres exists and is a DevWorldConfigData")
	if dev_world == null:
		return
	assert_ne(dev_world.world_seed, 0, "the development seed is set")
	assert_eq(GameManager.get_world_seed(), dev_world.world_seed, "GameManager holds that seed")
