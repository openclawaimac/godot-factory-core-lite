class_name FactoryMerger
extends FactoryNode
## N inputs, one output. One slot per input; each tick it forwards one item,
## rotating which input goes first, so inputs share the output fairly.

var slots: Dictionary[int, StringName] = {}
var _in_rr: int = 0

func kind() -> StringName:
	return &"merger"

func try_accept(item: StringName, from: FactoryNode) -> bool:
	var key: int = from.id if from else -1
	if slots.get(key, &"") != &"":
		return false
	slots[key] = item
	return true

func tick(_sim: FactorySim) -> void:
	var keys: Array[int] = []
	for k: int in slots:
		if slots[k] != &"":
			keys.append(k)
	if keys.is_empty():
		state = State.IDLE
		return
	keys.sort()
	var start: int = 0
	for i: int in keys.size():
		if keys[i] > _in_rr:
			start = i
			break
	var k: int = keys[start]
	if push_out(slots[k]):
		slots[k] = &""
		_in_rr = k
		state = State.WORKING
	else:
		state = State.BLOCKED

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	var s: Dictionary = {}
	for k: int in slots:
		s[str(k)] = String(slots[k])
	d.merge({"slots": s, "in_rr": _in_rr})
	return d

func load_state(d: Dictionary, db: FactoryDB) -> void:
	super.load_state(d, db)
	slots.clear()
	var s: Dictionary = d.get("slots", {})
	for k: Variant in s:
		slots[int(str(k))] = StringName(str(s[k]))
	_in_rr = int(d.get("in_rr", 0))
