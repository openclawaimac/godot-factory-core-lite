class_name FactoryBelt
extends FactoryNode
## A two-lane belt. Each lane is a FactoryBeltLane (gap model, integer
## sub-units, SUB per cell). Lane 0 = left lane, lane 1 = right lane, seen in
## the belt's direction. Lane choice on input:
## - from a belt directly behind: same lane as on that belt;
## - side-loading (a placed node at the belt's left/right side): the near lane;
## - anything else (machines, splitters, code-linked nodes): alternate lanes.
## One output.

const SUB: int = 256
const LANES: int = 2

var length_cells: int = 1
## Sub-units per tick (8 = 1.875 cells/s at 60 ticks/s).
var speed: int = 8
## Minimum item distance per lane (64 = 4 items per lane per cell).
var spacing: int = 64
var lanes: Array[FactoryBeltLane] = [FactoryBeltLane.new(), FactoryBeltLane.new()]
## Lane being pushed right now (read by the receiving belt); -1 when idle.
var pushing_lane: int = -1
var _in_rr: int = 0

func kind() -> StringName:
	return &"belt"

func length_sub() -> int:
	return length_cells * SUB

## Max items per lane when compressed.
func capacity() -> int:
	return maxi(1, length_sub() / spacing)

## Max items per second for the whole belt (both lanes).
func max_items_per_second(ticks_per_second: int) -> float:
	return float(speed) / spacing * ticks_per_second * LANES

## Total items on both lanes.
func item_count() -> int:
	return lanes[0].items.size() + lanes[1].items.size()

## Which lane an item from `from` should enter (-1 = alternate).
func lane_for(from: FactoryNode) -> int:
	if from != null and placed() and from.placed():
		var off: Vector2i = from.cell - cell
		if off == FactoryNode.DIRS[(dir + 3) % 4]:
			return 0
		if off == FactoryNode.DIRS[(dir + 1) % 4]:
			return 1
	if from is FactoryBelt and (from as FactoryBelt).pushing_lane >= 0:
		return (from as FactoryBelt).pushing_lane
	return -1

func try_accept(item: StringName, from: FactoryNode) -> bool:
	var lane: int = lane_for(from)
	if lane >= 0:
		return lanes[lane].accept(item, length_sub(), spacing, capacity())
	for k: int in LANES:
		var l: int = (_in_rr + k) % LANES
		if lanes[l].accept(item, length_sub(), spacing, capacity()):
			_in_rr = (l + 1) % LANES
			return true
	return false

func tick(_sim: FactorySim) -> void:
	if item_count() == 0:
		state = State.IDLE
		return
	var moved: bool = false
	for l: int in LANES:
		var lane: FactoryBeltLane = lanes[l]
		if lane.advance(speed, spacing):
			moved = true
		if lane.front_ready() and not outputs.is_empty():
			pushing_lane = l
			if push_out(lane.items[0]):
				lane.pop_front()
				moved = true
			pushing_lane = -1
	state = State.WORKING if moved else State.BLOCKED

## Last cell covered by this belt (a placed belt can span a straight run).
func tail_cell() -> Vector2i:
	return cell + FactoryNode.DIRS[dir] * (length_cells - 1)

## Cells covered by this belt, head first.
func covered_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: int in length_cells:
		out.append(cell + FactoryNode.DIRS[dir] * k)
	return out

## Position of item i on `lane` from the belt START, in cells.
func item_position_cells(lane: int, i: int) -> float:
	return float(lanes[lane].position_of(i, length_sub())) / SUB

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d.merge({"length_cells": length_cells, "speed": speed, "spacing": spacing,
		"in_rr": _in_rr, "lanes": [lanes[0].to_save(), lanes[1].to_save()]})
	return d

func load_state(d: Dictionary, db: FactoryDB) -> void:
	super.load_state(d, db)
	length_cells = int(d.get("length_cells", length_cells))
	speed = int(d.get("speed", speed))
	spacing = int(d.get("spacing", spacing))
	_in_rr = int(d.get("in_rr", 0))
	var ls: Array = d.get("lanes", [])
	for l: int in LANES:
		lanes[l].load_save(ls[l] if l < ls.size() else {})
