class_name FactoryNode
extends RefCounted
## Base class for everything in the factory graph. Items are pushed downstream:
## a node calls `push_out(item)`, which offers it to `outputs` round-robin via
## `try_accept(item, from)`. Subclasses override `try_accept`, `tick`, save hooks.

enum State { IDLE, WORKING, STARVED, BLOCKED, NO_POWER }

## Direction vectors indexed by `dir`: 0 east, 1 south, 2 west, 3 north.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

## Unique id assigned by FactorySim.add().
var id: int = -1
## Grid cell (for views only; simulation ignores it).
var cell: Vector2i = Vector2i.ZERO
## Facing (index into DIRS). Used by the builder and belts; ignored by code-linked graphs.
var dir: int = 0
## Id of the FactoryBuildable this node was placed from (empty = built in code).
var buildable_id: StringName = &""
var inputs: Array[FactoryNode] = []
var outputs: Array[FactoryNode] = []
var state: State = State.IDLE
var stats: FactoryStats = FactoryStats.new()
var _out_rr: int = 0

## True if placed on the grid (by your own code, or Pro's FactoryBuilder); geometry is meaningful.
func placed() -> bool:
	return buildable_id != &""

## Kind string used by save/load (override).
func kind() -> StringName:
	return &"node"

## Offer an item. Return true if taken (the caller then drops it).
func try_accept(_item: StringName, _from: FactoryNode) -> bool:
	return false

## Advance one simulation tick.
func tick(_sim: FactorySim) -> void:
	pass

## Power wanted this tick in watts (0 = not a consumer right now).
func power_demand() -> int:
	return 0

## Offers `item` to outputs round-robin (starting after the last success). True if delivered.
func push_out(item: StringName) -> bool:
	var n: int = outputs.size()
	for k: int in n:
		var o: FactoryNode = outputs[(_out_rr + k) % n]
		if o.try_accept(item, self):
			_out_rr = (_out_rr + k + 1) % n
			stats.note_out()
			o.stats.note_in()
			return true
	return false

## Node-specific state for saves (override and call super).
func save_state() -> Dictionary:
	return {"out_rr": _out_rr}

func load_state(d: Dictionary, _db: FactoryDB) -> void:
	_out_rr = int(d.get("out_rr", 0))

## Helper: Dictionary[StringName,int] -> JSON-safe {String: int}.
static func counts_to_json(c: Dictionary[StringName, int]) -> Dictionary:
	var out: Dictionary = {}
	for k: StringName in c:
		out[String(k)] = c[k]
	return out

static func counts_from_json(d: Variant) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if d is Dictionary:
		for k: Variant in d:
			out[StringName(str(k))] = int(d[k])
	return out
