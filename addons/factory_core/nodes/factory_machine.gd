class_name FactoryMachine
extends FactoryNode
## Crafts a FactoryRecipe. Input buffer holds up to `buffer_crafts` crafts of
## each input; output buffer up to `buffer_crafts` crafts of outputs.
## Progress scales with power satisfaction (always 100 % in Lite; Pro adds brownout).

var recipe: FactoryRecipe
var buffer_crafts: int = 2
var in_buf: Dictionary[StringName, int] = {}
var out_buf: Dictionary[StringName, int] = {}
var crafting: bool = false
## Progress in permille-ticks (1000 per tick at full power).
var progress: int = 0
var crafts_done: int = 0
var _sim_satisfaction: int = 1000

func _init(p_recipe: FactoryRecipe = null) -> void:
	recipe = p_recipe

func kind() -> StringName:
	return &"machine"

func try_accept(item: StringName, _from: FactoryNode) -> bool:
	if recipe == null or not recipe.inputs.has(item):
		return false
	if in_buf.get(item, 0) >= recipe.inputs[item] * buffer_crafts:
		return false
	in_buf[item] = in_buf.get(item, 0) + 1
	return true

func power_demand() -> int:
	if recipe == null:
		return 0
	if crafting or (_has_inputs() and _output_room()):
		return recipe.power_w
	return 0

func _has_inputs() -> bool:
	for k: StringName in recipe.inputs:
		if in_buf.get(k, 0) < recipe.inputs[k]:
			return false
	return true

func _output_room() -> bool:
	for k: StringName in recipe.outputs:
		if out_buf.get(k, 0) + recipe.outputs[k] > recipe.outputs[k] * buffer_crafts:
			return false
	return true

func tick(sim: FactorySim) -> void:
	if recipe == null:
		state = State.IDLE
		return
	var blocked: bool = false
	if not crafting:
		if not _output_room():
			blocked = true
		elif _has_inputs():
			for k: StringName in recipe.inputs:
				in_buf[k] -= recipe.inputs[k]
			crafting = true
			progress = 0
	var sat: int = sim.power.satisfaction_permille if recipe.power_w > 0 else 1000
	if crafting:
		progress += sat
		if progress >= recipe.time_ticks * 1000:
			for k: StringName in recipe.outputs:
				out_buf[k] = out_buf.get(k, 0) + recipe.outputs[k]
			crafting = false
			crafts_done += 1
	for k: StringName in out_buf.keys():
		if out_buf[k] > 0 and push_out(k):
			out_buf[k] -= 1
	if crafting:
		state = State.NO_POWER if sat == 0 else State.WORKING
	elif blocked:
		state = State.BLOCKED
	else:
		state = State.STARVED

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d.merge({"recipe": String(recipe.id) if recipe else "", "in_buf": counts_to_json(in_buf),
		"out_buf": counts_to_json(out_buf), "crafting": crafting, "progress": progress,
		"crafts_done": crafts_done, "buffer_crafts": buffer_crafts})
	return d

func load_state(d: Dictionary, db: FactoryDB) -> void:
	super.load_state(d, db)
	recipe = db.recipes.get(StringName(str(d.get("recipe", ""))))
	in_buf = counts_from_json(d.get("in_buf"))
	out_buf = counts_from_json(d.get("out_buf"))
	crafting = bool(d.get("crafting", false))
	progress = int(d.get("progress", 0))
	crafts_done = int(d.get("crafts_done", 0))
	buffer_crafts = int(d.get("buffer_crafts", 2))

