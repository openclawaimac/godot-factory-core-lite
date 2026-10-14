extends Node2D
## Factory Core Lite demo: the example chain (2 extractors -> merger -> smelter ->
## splitter -> plate storage + press -> gear storage) drawn with the CC0 sprites.
## Space pause, 1/2/3 speed x1/x2/x4, R restart. Sprites/sfx/font: CC0 (ASSET_LICENSES.md).

const CELL: float = 48.0
const ORIGIN: Vector2 = Vector2(208, 216)
const GRID: Vector2i = Vector2i(18, 7)
const SPR: String = "res://assets/sprites/%s.png"
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var chain: ProductionChain
var sim: FactorySim
var runner: FactorySimNode
var paused: bool = false
var speed_index: int = 0
var chimes: int = 0
var _last_gears: int = 0
var _tex: Dictionary[String, Texture2D] = {}
var _font: Font
var _sfx_gear: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = load("res://assets/fonts/kenney_mini_square.ttf") as Font
	_sfx_gear = _player("res://assets/sfx/place.ogg", -10.0)
	_sfx_click = _player("res://assets/sfx/select.ogg", -6.0)
	restart()

func _player(path: String, db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	p.volume_db = db
	add_child(p)
	return p

## (Re)builds the chain and its real-time runner.
func restart() -> void:
	if runner != null:
		runner.sim = null
		runner.queue_free()
		sim.dispose()
	chain = ProductionChain.build(ProductionChain.default_db())
	sim = chain.sim
	runner = FactorySimNode.new()
	runner.sim = sim
	add_child(runner)
	_last_gears = 0
	_apply_speed()

func toggle_pause() -> void:
	paused = not paused
	_apply_speed()

func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	_apply_speed()

func _apply_speed() -> void:
	runner.time_scale = 0.0 if paused else SPEEDS[speed_index]

func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(SPR % name) as Texture2D
	return _tex[name]

## Sprite name for a node at a given tick (animated while working).
static func sprite_for(n: FactoryNode, tick: int) -> String:
	var working: bool = n.state == FactoryNode.State.WORKING
	var f3: int = floori(tick / 8.0) % 3 if working else 0
	if n is FactorySource:
		return "extractor_%d" % (floori(tick / 10.0) % 2 if working else 0)
	if n is FactoryMerger:
		return "merger_%d" % f3
	if n is FactorySplitter:
		return "splitter_%d" % f3
	if n is FactorySink:
		return "sink"
	if n is FactoryMachine:
		var m: FactoryMachine = n as FactoryMachine
		if m.recipe != null and m.recipe.id == &"press_gear":
			return "press_%d" % f3
		return "smelt_%d" % f3 if working else "smelt_off"
	return "belt_0"

## Belt route in cell coordinates: an L from the input node to the output node.
## Splitter outputs turn first (vertical), everything else runs horizontal first.
static func belt_route(b: FactoryBelt) -> Array[Vector2i]:
	var a: Vector2i = b.inputs[0].cell
	var z: Vector2i = b.outputs[0].cell
	var corner: Vector2i = Vector2i(a.x, z.y) if b.inputs[0] is FactorySplitter else Vector2i(z.x, a.y)
	var pts: Array[Vector2i] = [a]
	if corner != a and corner != z:
		pts.append(corner)
	pts.append(z)
	return pts

## Point at fraction t (0..1) along a route, in cell units (cell centres).
static func route_point(pts: Array[Vector2i], t: float) -> Vector2:
	var total: float = 0.0
	for i: int in range(1, pts.size()):
		total += Vector2(pts[i] - pts[i - 1]).length()
	var d: float = clampf(t, 0.0, 1.0) * total
	for i: int in range(1, pts.size()):
		var seg: float = Vector2(pts[i] - pts[i - 1]).length()
		if d <= seg or i == pts.size() - 1:
			return Vector2(pts[i - 1]).lerp(Vector2(pts[i]), d / maxf(seg, 0.001)) + Vector2(0.5, 0.5)
		d -= seg
	return Vector2(pts[-1]) + Vector2(0.5, 0.5)

func _process(_delta: float) -> void:
	var g: int = chain.gear_sink.total()
	if g > _last_gears:
		chimes += g - _last_gears
		if not paused and _sfx_gear.stream != null and DisplayServer.get_name() != "headless":
			_sfx_gear.play()
	_last_gears = g
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE: toggle_pause()
		KEY_1: set_speed(0)
		KEY_2: set_speed(1)
		KEY_3: set_speed(2)
		KEY_R: restart()
		_: return
	if DisplayServer.get_name() != "headless":
		_sfx_click.play()

func _cell_rect(c: Vector2) -> Rect2:
	return Rect2(ORIGIN + c * CELL, Vector2(CELL, CELL))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.1, 0.12))
	for y: int in range(-1, GRID.y + 1):
		for x: int in range(-2, GRID.x + 1):
			draw_texture_rect(tex("ground_%d" % ((x * 7 + y * 13) & 3)), _cell_rect(Vector2(x, y)), false)
	var tick: int = sim.tick_count
	var bframe: String = "belt_%d" % (floori(tick / 4.0) % 4)
	for n: FactoryNode in sim.nodes:
		if n is FactorySource:
			draw_texture_rect(tex("dep_iron_0"), _cell_rect(Vector2(n.cell)), false)
	for n: FactoryNode in sim.nodes:
		if n is FactoryBelt and not n.inputs.is_empty() and not n.outputs.is_empty():
			_draw_belt(n as FactoryBelt, bframe)
	for n: FactoryNode in sim.nodes:
		if n is FactoryBelt:
			continue
		var r: Rect2 = _cell_rect(Vector2(n.cell)).grow(6.0)
		draw_rect(Rect2(r.position + Vector2(4, 8), r.size), Color(0, 0, 0, 0.35))
		draw_texture_rect(tex(sprite_for(n, tick)), r, false)
		if n is FactorySink:
			var cnt: int = (n as FactorySink).total()
			var icon: String = "item_gear" if n == chain.gear_sink else "item_plate"
			draw_texture_rect(tex(icon), Rect2(r.position + Vector2(8, -30), Vector2(24, 24)), false)
			draw_string(_font, r.position + Vector2(36, -10), str(cnt), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_draw_hud()

func _draw_belt(b: FactoryBelt, frame: String) -> void:
	var pts: Array[Vector2i] = belt_route(b)
	for i: int in range(1, pts.size()):
		var step: Vector2i = (pts[i] - pts[i - 1]).sign()
		var c: Vector2i = pts[i - 1]
		while c != pts[i]:
			if i > 1 or c != pts[0]:
				_draw_rot(tex(frame), Vector2(c), Vector2(step).angle())
			c += step
	for l: int in FactoryBelt.LANES:
		var lane: FactoryBeltLane = b.lanes[l]
		for j: int in lane.items.size():
			var t: float = b.item_position_cells(l, j) / float(b.length_cells)
			var p: Vector2 = ORIGIN + route_point(pts, t) * CELL + Vector2(0, (l - 0.5) * 14.0)
			draw_texture_rect(tex("item_%s" % lane.items[j]), Rect2(p - Vector2(10, 10), Vector2(20, 20)), false)

func _draw_rot(t: Texture2D, cell: Vector2, ang: float) -> void:
	var c: Vector2 = ORIGIN + (cell + Vector2(0.5, 0.5)) * CELL
	draw_set_transform(c, ang, Vector2.ONE)
	draw_texture_rect(t, Rect2(-CELL * 0.5, -CELL * 0.5, CELL, CELL), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 120), Color(0, 0, 0, 0.55))
	draw_string(_font, Vector2(40, 58), "FACTORY CORE LITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.82, 0.35))
	draw_string(_font, Vector2(40, 96), "ore > plate > gear   |   deterministic 60-tick sim   |   free MIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.85, 0.9))
	var stat: String = "PAUSED" if paused else "x%d" % int(SPEEDS[speed_index])
	draw_string(_font, Vector2(900, 58), "%s   %.1f s" % [stat, sim.tick_count / float(FactorySim.TICKS_PER_SECOND)], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_rect(Rect2(0, 664, 1280, 56), Color(0, 0, 0, 0.55))
	draw_string(_font, Vector2(40, 700), "SPACE pause   1 2 3 speed   R restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.85, 0.9))
	draw_string(_font, Vector2(820, 700), "CC0 art + Kenney sfx/font", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.65, 0.7))

func _exit_tree() -> void:
	sim.dispose()
