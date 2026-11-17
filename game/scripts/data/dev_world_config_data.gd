class_name DevWorldConfigData
extends Resource
## Fixed world used during development, until worlds are created and saved
## (spec 010 replaces it with the seed of the saved world).

## Not a balance value: it only makes the generated zone reproducible.
@export var world_seed: int = 0
## Id of the world's RulesetData. The World file stores the id, never the
## resource (PMV §4.5 hook 4).
@export var ruleset_id: StringName
