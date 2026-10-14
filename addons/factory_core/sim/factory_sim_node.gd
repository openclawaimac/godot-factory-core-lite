class_name FactorySimNode
extends Node
## Drives a FactorySim from the scene tree at FactorySim.TICKS_PER_SECOND,
## using a fixed-step accumulator (frame rate does not change results).

var sim: FactorySim
## Speed multiplier (1 = real time). 0 pauses.
@export var time_scale: float = 1.0
## Safety cap on ticks per frame.
@export var max_ticks_per_frame: int = 240
var _acc: float = 0.0

func _physics_process(delta: float) -> void:
	if sim == null or time_scale <= 0.0:
		return
	_acc += delta * time_scale * FactorySim.TICKS_PER_SECOND
	var n: int = mini(int(_acc), max_ticks_per_frame)
	_acc -= n
	sim.step(n)
