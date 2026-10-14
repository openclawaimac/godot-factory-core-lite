class_name FactoryView
extends Node2D
## Debug/fallback renderer. Placed nodes are squares at their cell (belts: a
## strip with a direction tick and two lanes of item dots). Code-linked belts
## are drawn as lines between their ends. With `show_state`, colour shows each
## node's state (idle/working/starved/blocked). Pro adds a bottleneck overlay.

@export var cell_px: float = 32.0
@export var show_state: bool = true
var sim: FactorySim

const STATE_COLORS: Array[Color] = [Color(0.4, 0.4, 0.45), Color(0.3, 0.8, 0.4), Color(0.9, 0.8, 0.2), Color(0.95, 0.4, 0.2), Color(0.5, 0.3, 0.9)]

func _process(_delta: float) -> void:
	queue_redraw()

## Pixel centre of a cell (local coordinates).
func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * cell_px

## Cell under a local position.
func cell_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / cell_px), floori(local.y / cell_px))

func _node_color(n: FactoryNode) -> Color:
	if show_state:
		return STATE_COLORS[n.state]
	var b: FactoryBuildable = sim.db.buildables.get(n.buildable_id)
	return b.color if b else Color(0.6, 0.6, 0.65)

func _draw() -> void:
	if sim == null:
		return
	for n: FactoryNode in sim.nodes:
		if n is FactoryBelt:
			_draw_belt(n as FactoryBelt)
	for n: FactoryNode in sim.nodes:
		if n is FactoryBelt:
			continue
		var c: Vector2 = cell_center(n.cell)
		var h: float = cell_px * 0.42
		draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), _node_color(n))
		if n.placed():
			draw_line(c, c + Vector2(FactoryNode.DIRS[n.dir]) * h, Color.BLACK, 2.0)

func _draw_belt(b: FactoryBelt) -> void:
	var a: Vector2
	var z: Vector2
	if b.placed():
		var d: Vector2 = Vector2(FactoryNode.DIRS[b.dir])
		a = cell_center(b.cell) - d * cell_px * 0.5
		z = a + d * cell_px * b.length_cells
		var col: Color = _node_color(b).darkened(0.35)
		draw_line(a, z, col, cell_px * 0.6)
		draw_line(cell_center(b.cell), cell_center(b.cell) + d * cell_px * 0.3, Color(0, 0, 0, 0.6), 2.0)
	elif not b.inputs.is_empty() and not b.outputs.is_empty():
		a = cell_center(b.inputs[0].cell)
		z = cell_center(b.outputs[0].cell)
		draw_line(a, z, _node_color(b).darkened(0.3), 8.0)
	else:
		return
	var dir_v: Vector2 = (z - a).normalized()
	var left: Vector2 = Vector2(dir_v.y, -dir_v.x)
	for l: int in FactoryBelt.LANES:
		var off: Vector2 = left * (cell_px * 0.14) * (1.0 if l == 0 else -1.0)
		var lane: FactoryBeltLane = b.lanes[l]
		for i: int in lane.items.size():
			var t: float = b.item_position_cells(l, i) / float(b.length_cells)
			draw_circle(a.lerp(z, t) + off, cell_px * 0.1, sim.db.color_of(lane.items[i]))
