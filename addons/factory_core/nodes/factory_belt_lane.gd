class_name FactoryBeltLane
extends RefCounted
## One lane of a belt, stored as items + integer GAPS (not positions):
## gaps[0] = distance of the front item to the lane end, gaps[i] = distance of
## item i to item i-1. A free-flowing lane only changes gaps[0] per tick.

var items: Array[StringName] = []
var gaps: PackedInt32Array = PackedInt32Array()
## Sum of gaps = distance of the last item from the end.
var total: int = 0

## Adds an item at the lane start if there is room. True if added.
func accept(item: StringName, length: int, spacing: int, capacity: int) -> bool:
	var free: int = length - total
	if not items.is_empty() and (free < spacing or items.size() >= capacity):
		return false
	items.append(item)
	gaps.append(free)
	total += free
	return true

## Moves items by `speed`, compressing behind a stopped front. True if anything moved.
func advance(speed: int, spacing: int) -> bool:
	if items.is_empty():
		return false
	var d: int = mini(speed, gaps[0])
	gaps[0] -= d
	total -= d
	var moved: bool = d > 0
	var leftover: int = speed - d
	var i: int = 1
	while leftover > 0 and i < gaps.size():
		var c: int = clampi(gaps[i] - spacing, 0, leftover)
		gaps[i] -= c
		total -= c
		moved = moved or c > 0
		leftover -= c
		i += 1
	return moved

## True if the front item has reached the end.
func front_ready() -> bool:
	return not items.is_empty() and gaps[0] == 0

func pop_front() -> void:
	items.remove_at(0)
	gaps.remove_at(0)

## Distance of item i from the lane START in sub-units.
func position_of(i: int, length: int) -> int:
	var from_end: int = 0
	for k: int in i + 1:
		from_end += gaps[k]
	return length - from_end

## Positions (from lane start) of every item, front first.
func positions(length: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var from_end: int = 0
	for k: int in gaps.size():
		from_end += gaps[k]
		out.append(length - from_end)
	return out

## Replaces the lane with `p_items` at `p_positions` (from start, front first, non-increasing).
func set_positions(p_items: Array[StringName], p_positions: PackedInt32Array, length: int) -> void:
	items = p_items.duplicate()
	gaps = PackedInt32Array()
	total = 0
	var prev: int = length
	for k: int in p_items.size():
		var g: int = maxi(0, prev - p_positions[k])
		gaps.append(g)
		total += g
		prev = p_positions[k]

func to_save() -> Dictionary:
	var its: Array = []
	for it: StringName in items:
		its.append(String(it))
	return {"items": its, "gaps": Array(gaps)}

func load_save(d: Dictionary) -> void:
	items.clear()
	gaps = PackedInt32Array()
	total = 0
	var its: Array = d.get("items", [])
	var gs: Array = d.get("gaps", [])
	for k: int in its.size():
		items.append(StringName(str(its[k])))
		gaps.append(int(gs[k]))
		total += int(gs[k])
