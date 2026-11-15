class_name DevWorldConfigData
extends Resource
## Fixed world used during development, until worlds are created and saved
## (spec 010 replaces it with the seed of the saved world).

## Not a balance value: it only makes the generated zone reproducible.
@export var world_seed: int = 0
