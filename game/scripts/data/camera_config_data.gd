class_name CameraConfigData
extends Resource
## Isometric camera framing (BALANCE.md §11). Orthographic projection:
## ortho_size is the vertical extent in meters (keep_aspect = KEEP_HEIGHT).

@export var yaw_degrees: float = 0.0
@export var pitch_degrees: float = 0.0
## Physical distance to the target; only near/far and shadows, not framing.
@export var distance: float = 0.0
@export var ortho_size: float = 0.0
