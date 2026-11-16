class_name ImpactSparks
extends Node3D
## One burst of sparks where a hit lands (spec 007, R-007-24). Pooled
## (R-007-27): play() starts the burst again and finished says when the
## instance can go back to its pool. Placeholder look until ACTION_PLAN 4.4.

## The burst is over.
signal finished(sparks: ImpactSparks)

@onready var _particles: GPUParticles3D = %Particles


func _ready() -> void:
	_particles.finished.connect(_on_particles_finished)


## Starts the burst from the beginning. Call it inside the tree.
func play() -> void:
	_particles.restart()


func _on_particles_finished() -> void:
	finished.emit(self)
