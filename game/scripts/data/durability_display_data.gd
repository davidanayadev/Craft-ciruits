class_name DurabilityDisplayData
extends Resource
## Colour bands of a piece's durability bar (spec 015, R-015-32, BALANCE
## §4.1): green above yellow_up_to_percent, yellow down to just above the red
## threshold, red at or below it. The red threshold is not stored: it is the
## up_to_percent of the first repair tier ("muy dañada"), so it lives in one
## .tres only (plan 015 D18). The colours themselves are presentation.

enum Band { GREEN, YELLOW, RED }

## Highest durability left, in percent of the maximum, that is still yellow.
@export var yellow_up_to_percent: int = 0
## The repair tiers; its first tier is the red band (BALANCE §4.1, §4.3.2).
@export var repair_costs: RepairCostData


## RED at or below the red threshold of maximum, YELLOW at or below
## yellow_up_to_percent, else GREEN. maximum <= 0 or no repair tier →
## push_error, RED.
func band_of(durability: int, maximum: int) -> Band:
	if maximum <= 0 or repair_costs == null or repair_costs.tiers.is_empty() or repair_costs.tiers[0] == null:
		push_error("DurabilityDisplayData: band_of() needs a maximum above 0 and a first repair tier.")
		return Band.RED
	var scaled: int = durability * CraftingSystem.PERCENT
	if scaled <= repair_costs.tiers[0].up_to_percent * maximum:
		return Band.RED
	if scaled <= yellow_up_to_percent * maximum:
		return Band.YELLOW
	return Band.GREEN
