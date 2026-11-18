class_name RecipeData
extends Resource
## A recipe (ACTION_PLAN 2.4, PMV §4.5 hook 5): the structures built at the
## repair bench (spec 009) and the items crafted there (spec 011). Every catalog
## recipe sets exactly one of result_structure and result_item (R-011-03).

## Where it is crafted (SPECS.md §29): by hand, with nanobots or at the workbench.
enum Station { SELF, NANOBOTS, WORKBENCH }

## snake_case and stable forever (architecture §8).
@export var id: StringName
@export var ingredients: Array[RecipeIngredientData] = []
@export var station: Station = Station.WORKBENCH
@export var tier: int = 1
## Ids of what must be unlocked first; none in the MVP.
@export var requires: Array[StringName] = []
@export var result_structure: StructureData
## The item it makes, one unit (spec 011); null for a structure recipe.
@export var result_item: ItemData
