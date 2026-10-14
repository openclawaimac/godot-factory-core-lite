class_name FactorySink
extends FactoryNode
## Accepts anything (or only `accepts` if non-empty) and counts it. Use as a
## storage/goal endpoint. `rate_limit_ticks` > 0 accepts at most 1 item per that many ticks.

var accepts: Array[StringName] = []
var received: Dictionary[StringName, int] = {}
var rate_limit_ticks: int = 0
var _cooldown: int = 0

func kind() -> StringName:
	return &"sink"

func try_accept(item: StringName, _from: FactoryNode) -> bool:
	if not accepts.is_empty() and not accepts.has(item):
		return false
	if _cooldown > 0:
		return false
	received[item] = received.get(item, 0) + 1
	_cooldown = rate_limit_ticks
	return true

func total() -> int:
	var n: int = 0
	for k: StringName in received:
		n += received[k]
	return n

func tick(_sim: FactorySim) -> void:
	if _cooldown > 0:
		_cooldown -= 1
	state = State.WORKING if stats.total_in > 0 else State.STARVED

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	var acc: Array = []
	for a: StringName in accepts:
		acc.append(String(a))
	d.merge({"accepts": acc, "received": counts_to_json(received), "rate_limit_ticks": rate_limit_ticks, "cooldown": _cooldown})
	return d

func load_state(d: Dictionary, db: FactoryDB) -> void:
	super.load_state(d, db)
	accepts.clear()
	for a: Variant in d.get("accepts", []):
		accepts.append(StringName(str(a)))
	received = counts_from_json(d.get("received"))
	rate_limit_ticks = int(d.get("rate_limit_ticks", 0))
	_cooldown = int(d.get("cooldown", 0))
