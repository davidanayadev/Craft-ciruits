extends GutTest
## DurabilityDisplayData (spec 015, R-015-32): green above 50 %, yellow from
## 50 % down to just above 25 %, red at 25 % or less (BALANCE §4.1), the red
## threshold taken from the first repair tier (plan D18).

const DISPLAY_PATH := "res://resources/config/durability_display.tres"

const GREEN := DurabilityDisplayData.Band.GREEN
const YELLOW := DurabilityDisplayData.Band.YELLOW
const RED := DurabilityDisplayData.Band.RED


func _display() -> DurabilityDisplayData:
	return load(DISPLAY_PATH) as DurabilityDisplayData


func test_r_015_32_bands() -> void:
	var display: DurabilityDisplayData = _display()
	assert_eq(display.yellow_up_to_percent, 50, "yellow up to 50 % (BALANCE §4.1)")
	assert_eq(display.band_of(51, 100), GREEN, "51/100 green")
	assert_eq(display.band_of(50, 100), YELLOW, "50/100 yellow")
	assert_eq(display.band_of(26, 100), YELLOW, "26/100 yellow")
	assert_eq(display.band_of(25, 100), RED, "25/100 red")
	assert_eq(display.band_of(1, 100), RED, "1/100 red")
	assert_eq(display.band_of(101, 200), GREEN, "50.5 % green")
	assert_eq(display.band_of(100, 200), YELLOW, "50 % of 200 yellow")
	assert_eq(display.band_of(51, 200), YELLOW, "25.5 % yellow")
	assert_eq(display.band_of(50, 200), RED, "25 % of 200 red")


func test_r_015_32_red_comes_from_first_repair_tier() -> void:
	var first: RepairTierData = RepairTierData.new()
	first.up_to_percent = 10
	var last: RepairTierData = RepairTierData.new()
	last.up_to_percent = 100
	var costs: RepairCostData = RepairCostData.new()
	costs.tiers = [first, last]
	var display: DurabilityDisplayData = DurabilityDisplayData.new()
	display.yellow_up_to_percent = 50
	display.repair_costs = costs
	assert_eq(display.band_of(10, 100), RED, "red at the first tier's limit")
	assert_eq(display.band_of(11, 100), YELLOW, "yellow just above it")
	var real: DurabilityDisplayData = _display()
	assert_eq(real.repair_costs.tiers[0].up_to_percent, 25, "the real red threshold is the 'muy dañada' tier")


func test_r_015_32_bad_data_reported_red() -> void:
	var display: DurabilityDisplayData = DurabilityDisplayData.new()
	display.yellow_up_to_percent = 50
	assert_eq(display.band_of(80, 100), RED, "no repair tiers")
	assert_push_error("DurabilityDisplayData")
	assert_eq(_display().band_of(5, 0), RED, "a maximum of 0")
	assert_push_error_count(2, "both reported")
