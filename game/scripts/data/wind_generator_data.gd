class_name WindGeneratorData
extends StructureData
## The wind generator (spec 012, BALANCE §5.2): every number of it lives here (R-012-04).

## Points added to the maximum battery of every player robot while one is placed.
@export var max_battery_bonus: float = 0.0
## Seconds to make one portable battery.
@export var seconds_per_battery: int = 0
## Batteries it holds at most.
@export var max_stored: int = 0
## What it makes (the portable battery).
@export var battery_item: ItemData
