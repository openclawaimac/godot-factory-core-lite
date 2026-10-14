class_name FactoryRecipe
extends Resource
## A machine recipe: consumes `inputs`, waits `time_ticks` (at full power), yields `outputs`.

@export var id: StringName
@export var inputs: Dictionary[StringName, int] = {}
@export var outputs: Dictionary[StringName, int] = {}
## Craft time in simulation ticks at 100% power (FactorySim.TICKS_PER_SECOND per second).
@export var time_ticks: int = 60
## Power drawn while crafting, in watts.
@export var power_w: int = 100

static func make(p_id: StringName, p_in: Dictionary[StringName, int], p_out: Dictionary[StringName, int],
		p_ticks: int, p_power: int = 100) -> FactoryRecipe:
	var r: FactoryRecipe = FactoryRecipe.new()
	r.id = p_id
	r.inputs = p_in
	r.outputs = p_out
	r.time_ticks = p_ticks
	r.power_w = p_power
	return r
