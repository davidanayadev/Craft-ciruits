extends GutTest
## Structure data (spec 009, R-009-24): the charging station is the first
## StructureData, with the footprint of BALANCE §5.6, and structures do not
## rotate. The expected values mirror BALANCE.md §5.6; update both together.

const STATION_PATH := "res://resources/structures/charging_station.tres"


func test_r_009_24_charging_station_footprint() -> void:
	var station: StructureData = load(STATION_PATH) as StructureData
	assert_not_null(station, "charging_station.tres exists and is a StructureData")
	if station == null:
		return
	assert_eq(station.id, &"charging_station", "stable id")
	assert_eq(station.name_key, &"STRUCTURE_CHARGING_STATION", "name key")
	assert_eq(station.footprint, Vector2i(1, 1), "footprint 1x1 (BALANCE §5.6)")


func test_r_009_24_no_rotation_field() -> void:
	# No rotation in the MVP (BALANCE §5.6): neither the data nor the saved state has one.
	var names: Array[String] = []
	for property: Dictionary in StructureData.new().get_property_list():
		var property_name: String = property["name"]
		names.append(property_name)
	for forbidden: String in ["rotation", "orientation", "facing"]:
		assert_false(names.has(forbidden), "StructureData has no '%s'" % forbidden)
