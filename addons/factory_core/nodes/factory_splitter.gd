class_name FactorySplitter
extends FactoryNode
## One input, N outputs. Alternates outputs; if one is blocked the item goes to
## the next free one.

var held: StringName = &""

func kind() -> StringName:
	return &"splitter"

func try_accept(item: StringName, _from: FactoryNode) -> bool:
	if held != &"":
		return false
	held = item
	return true

func tick(_sim: FactorySim) -> void:
	if held == &"":
		state = State.IDLE
		return
	var ok: bool = push_out(held)
	if ok:
		held = &""
		state = State.WORKING
	else:
		state = State.BLOCKED

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d.merge({"held": String(held)})
	return d

func load_state(d: Dictionary, db: FactoryDB) -> void:
	super.load_state(d, db)
	held = StringName(str(d.get("held", "")))
