class_name FactorySim
extends RefCounted
## Owns the factory graph and advances it in fixed, deterministic ticks.
## No physics, no frame delta: the same inputs always give the same state.
## Use FactorySimNode to drive it from the scene tree in real time.

const TICKS_PER_SECOND: int = 60
const SAVE_FORMAT: String = "factory-core-save"
const SAVE_VERSION: int = 2

## Emitted after each tick.
signal ticked(tick: int)

var db: FactoryDB
var nodes: Array[FactoryNode] = []
var power: FactoryPowerGrid = FactoryPowerGrid.new()
var tick_count: int = 0
var _next_id: int = 0
## Last load error (empty on success).
var last_error: String = ""
var _by_id: Dictionary[int, FactoryNode] = {}

## Save/load factory: kind -> Callable() -> FactoryNode. Register custom kinds here.
static var KINDS: Dictionary[StringName, Callable] = {
	&"belt": func() -> FactoryNode: return FactoryBelt.new(),
	&"machine": func() -> FactoryNode: return FactoryMachine.new(),
	&"source": func() -> FactoryNode: return FactorySource.new(),
	&"sink": func() -> FactoryNode: return FactorySink.new(),
	&"splitter": func() -> FactoryNode: return FactorySplitter.new(),
	&"merger": func() -> FactoryNode: return FactoryMerger.new(),
}

func _init(p_db: FactoryDB = null) -> void:
	db = p_db if p_db else FactoryDB.new()

## Adds a node, assigns its id and returns it (for chaining).
func add(n: FactoryNode, cell: Vector2i = Vector2i.ZERO) -> FactoryNode:
	n.id = _next_id
	_next_id += 1
	n.cell = cell
	nodes.append(n)
	_by_id[n.id] = n
	return n

## Connects a -> b (items flow from a to b).
func connect_nodes(a: FactoryNode, b: FactoryNode) -> void:
	a.outputs.append(b)
	b.inputs.append(a)

## Convenience: a -> new belt -> b. Returns the belt.
func link(a: FactoryNode, b: FactoryNode, length_cells: int = 3) -> FactoryBelt:
	var belt: FactoryBelt = add(FactoryBelt.new(), a.cell) as FactoryBelt
	belt.length_cells = length_cells
	connect_nodes(a, belt)
	connect_nodes(belt, b)
	return belt

func get_node_by_id(id: int) -> FactoryNode:
	return _by_id.get(id)

## Breaks node<->node references so the graph can be freed. Call when done
## with a sim (RefCounted cycles are otherwise leaked). Leaves the sim empty.
func dispose() -> void:
	for n: FactoryNode in nodes:
		n.inputs.clear()
		n.outputs.clear()
	nodes.clear()
	_by_id.clear()

## Advances `ticks` simulation ticks (default 1).
func step(ticks: int = 1) -> void:
	for t: int in ticks:
		power.update(nodes)
		for n: FactoryNode in nodes:
			n.tick(self)
		for n: FactoryNode in nodes:
			n.stats.record(n.state)
		tick_count += 1
		ticked.emit(tick_count)

## Per-node report: {id, kind, state ratios, per_minute}. Sorted by id.
func report() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: FactoryNode in nodes:
		out.append({"id": n.id, "kind": n.kind(), "working": n.stats.ratio(FactoryNode.State.WORKING),
			"starved": n.stats.ratio(FactoryNode.State.STARVED), "blocked": n.stats.ratio(FactoryNode.State.BLOCKED),
			"no_power": n.stats.ratio(FactoryNode.State.NO_POWER), "per_minute": n.stats.per_minute(TICKS_PER_SECOND)})
	return out

## JSON-safe snapshot of the whole graph (stats are not saved).
func to_save() -> Dictionary:
	var list: Array = []
	for n: FactoryNode in nodes:
		var outs: Array = []
		for o: FactoryNode in n.outputs:
			outs.append(o.id)
		list.append({"id": n.id, "kind": String(n.kind()), "cx": n.cell.x, "cy": n.cell.y, "dir": n.dir,
			"bid": String(n.buildable_id), "outputs": outs, "state": n.save_state()})
	return {"format": SAVE_FORMAT, "version": SAVE_VERSION, "tick": tick_count, "next_id": _next_id, "nodes": list}

## Replaces the graph with a snapshot. Returns false on bad format/version or unknown kind.
func load_save(d: Dictionary) -> bool:
	if str(d.get("format", "")) != SAVE_FORMAT or int(d.get("version", 0)) > SAVE_VERSION:
		last_error = "unsupported save format/version"
		return false
	if int(d.get("version", 1)) != SAVE_VERSION:
		# Lite reads only the current format. Pro migrates older saves.
		last_error = "save version %d not supported (Lite reads v%d only)" % [int(d.get("version", 1)), SAVE_VERSION]
		return false
	d = d.duplicate(true)
	var list: Array = d.get("nodes", [])
	var made: Dictionary[int, FactoryNode] = {}
	for e: Variant in list:
		var ed: Dictionary = e
		var k: StringName = StringName(str(ed.get("kind", "")))
		if not KINDS.has(k):
			last_error = "unknown node kind %s" % k
			return false
		var n: FactoryNode = KINDS[k].call()
		n.id = int(ed["id"])
		n.cell = Vector2i(int(ed.get("cx", 0)), int(ed.get("cy", 0)))
		n.dir = int(ed.get("dir", 0))
		n.buildable_id = StringName(str(ed.get("bid", "")))
		n.load_state(ed.get("state", {}), db)
		made[n.id] = n
	dispose()
	var ids: Array[int] = []
	ids.assign(made.keys())
	ids.sort()
	for id: int in ids:
		nodes.append(made[id])
		_by_id[id] = made[id]
	for e: Variant in list:
		var ed: Dictionary = e
		var a: FactoryNode = made[int(ed["id"])]
		for o: Variant in ed.get("outputs", []):
			connect_nodes(a, made[int(o)])
	last_error = ""
	tick_count = int(d.get("tick", 0))
	_next_id = int(d.get("next_id", ids.size()))
	return true

## Removes a node and all its links (items inside it are lost).
func remove_node(n: FactoryNode) -> void:
	for o: FactoryNode in n.outputs:
		o.inputs.erase(n)
	for i: FactoryNode in n.inputs:
		i.outputs.erase(n)
	n.inputs.clear()
	n.outputs.clear()
	nodes.erase(n)
	_by_id.erase(n.id)

## Removes all outgoing links of `n`.
func disconnect_outputs(n: FactoryNode) -> void:
	for o: FactoryNode in n.outputs:
		o.inputs.erase(n)
	n.outputs.clear()

## Writes JSON to `path`. Returns OK or an error.
func save_file(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_save(), "\t"))
	f.close()
	return OK

## Reads JSON from `path`. Returns OK, ERR_FILE_NOT_FOUND, ERR_PARSE_ERROR or ERR_INVALID_DATA.
func load_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var j: JSON = JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not j.data is Dictionary:
		return ERR_PARSE_ERROR
	return OK if load_save(j.data) else ERR_INVALID_DATA
