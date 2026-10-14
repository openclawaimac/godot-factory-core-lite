class_name FactorySource
extends FactoryNode
## Extractor: creates `item` every `interval_ticks` (scaled by power if power_w > 0)
## into a small output buffer, then pushes downstream.

var item: StringName = &"ore"
var interval_ticks: int = 30
var power_w: int = 0
var buffer_max: int = 2
var buffered: int = 0
var progress: int = 0
var _wants_power: bool = true

func kind() -> StringName:
	return &"source"

func power_demand() -> int:
	return power_w if buffered < buffer_max else 0

func tick(sim: FactorySim) -> void:
	var sat: int = sim.power.satisfaction_permille if power_w > 0 else 1000
	var blocked: bool = buffered >= buffer_max
	if not blocked:
		progress += sat
		if progress >= interval_ticks * 1000:
			progress -= interval_ticks * 1000
			buffered += 1
	if buffered > 0 and push_out(item):
		buffered -= 1
	if blocked and buffered >= buffer_max:
		state = State.BLOCKED
	elif sat == 0:
		state = State.NO_POWER
	else:
		state = State.WORKING

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d.merge({"item": String(item), "interval_ticks": interval_ticks, "power_w": power_w,
		"buffer_max": buffer_max, "buffered": buffered, "progress": progress})
	return d

func load_state(d: Dictionary, db: FactoryDB) -> void:
	super.load_state(d, db)
	item = StringName(str(d.get("item", item)))
	interval_ticks = int(d.get("interval_ticks", interval_ticks))
	power_w = int(d.get("power_w", power_w))
	buffer_max = int(d.get("buffer_max", buffer_max))
	buffered = int(d.get("buffered", 0))
	progress = int(d.get("progress", 0))
