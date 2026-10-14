extends SceneTree
## Lite headless tests: tools/run_tests.sh (strict) or
## godot --headless --path . -s res://tests/run_tests.gd  (exit 0 = pass).
## Subset of the Pro suite for the Lite modules, plus Lite-only checks.

const Harness = preload("res://tests/harness.gd")
var H: Harness
var _sims: Array[FactorySim] = []

func track(s: FactorySim) -> FactorySim:
	_sims.append(s)
	return s

func check(cond: bool, msg: String) -> void:
	H.check(cond, msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	H = Harness.new()
	if Harness.selftest_mode() == "crash":
		await H.section("harness_crash_selftest", H.crash_selftest)
	elif Harness.selftest_mode() == "exit":
		quit(0)
		return
	await H.section("test_belt", test_belt)
	await H.section("test_machine", test_machine)
	await H.section("test_splitter", test_splitter)
	await H.section("test_merger", test_merger)
	await H.section("test_power_stub", test_power_stub)
	await H.section("test_chain", test_chain)
	await H.section("test_determinism_and_save", test_determinism_and_save)
	await H.section("test_save_file", test_save_file)
	await H.section("test_save_version", test_save_version)
	await H.section("test_json_content", test_json_content)
	await H.section("test_lite_scope", test_lite_scope)
	await H.section("test_view_scene", test_view_scene)
	await H.section("test_demo", test_demo)
	for sm: FactorySim in _sims:
		sm.dispose()
	_sims.clear()
	quit(H.finish())

func _db() -> FactoryDB:
	return ProductionChain.default_db()

func _chain() -> ProductionChain:
	var c: ProductionChain = ProductionChain.build(_db())
	track(c.sim)
	return c

func test_belt() -> void:
	print("belt (two-lane gap model)")
	var s: FactorySim = track(FactorySim.new(_db()))
	var belt: FactoryBelt = s.add(FactoryBelt.new()) as FactoryBelt
	belt.length_cells = 2
	var sink: FactorySink = s.add(FactorySink.new()) as FactorySink
	s.connect_nodes(belt, sink)
	check(belt.try_accept(&"ore", null) and belt.lanes[0].items.size() == 1, "empty belt accepts onto lane 0")
	check(belt.try_accept(&"ore", null) and belt.lanes[1].items.size() == 1, "second item alternates to lane 1")
	check(not belt.try_accept(&"ore", null), "rejects until spacing is free on both lanes")
	s.step(63)
	check(sink.total() == 0 and belt.lanes[0].gaps[0] == 512 - 63 * 8, "items moved 8 sub-units per tick (gap %d)" % belt.lanes[0].gaps[0])
	s.step(1)
	check(sink.total() == 2 and belt.item_count() == 0, "both lanes deliver after length/speed = 64 ticks")
	var blocked: FactoryBelt = s.add(FactoryBelt.new()) as FactoryBelt
	blocked.length_cells = 2
	var fed: int = 0
	for t: int in 400:
		if blocked.try_accept(&"ore", null):
			fed += 1
		s.step(1)
	check(blocked.item_count() == 16 and fed == 16, "blocked belt compresses to 2 lanes x 2 cells x 4 = 16 (%d)" % blocked.item_count())
	var ok: bool = true
	for lane: FactoryBeltLane in blocked.lanes:
		ok = ok and lane.gaps[0] == 0
		for i: int in range(1, lane.gaps.size()):
			ok = ok and lane.gaps[i] == blocked.spacing
	check(ok and blocked.state == FactoryNode.State.BLOCKED, "compressed gaps == spacing, state BLOCKED")
	var free: FactoryBelt = s.add(FactoryBelt.new()) as FactoryBelt
	free.length_cells = 8
	free.try_accept(&"a", null)
	s.step(20)
	free.try_accept(&"b", null)
	free.try_accept(&"c", null)
	var g1: int = free.lanes[0].gaps[1]
	s.step(30)
	check(free.lanes[0].gaps[1] == g1, "while the front moves, gaps behind are untouched (O(1) update)")
	check(is_equal_approx(free.max_items_per_second(60), 15.0), "max throughput 15 items/s (2 lanes x 7.5)")

func test_machine() -> void:
	print("machine")
	var db: FactoryDB = _db()
	var s: FactorySim = track(FactorySim.new(db))
	var m: FactoryMachine = s.add(FactoryMachine.new(db.recipes[&"press_gear"])) as FactoryMachine
	check(not m.try_accept(&"ore", null), "rejects items not in recipe")
	check(m.try_accept(&"plate", null) and m.try_accept(&"plate", null) and m.try_accept(&"plate", null) and m.try_accept(&"plate", null), "buffers 2 crafts of input")
	check(not m.try_accept(&"plate", null), "input buffer full")
	s.step(1)
	check(m.crafting and m.state == FactoryNode.State.WORKING, "starts crafting when inputs present")
	s.step(45)
	check(m.crafts_done == 1 and m.out_buf[&"gear"] == 1, "crafts after time_ticks (45)")
	s.step(100)
	check(m.crafts_done == 2 and m.state == FactoryNode.State.BLOCKED, "no output link -> output buffer full -> BLOCKED")
	var idle: FactoryMachine = s.add(FactoryMachine.new(db.recipes[&"smelt_plate"])) as FactoryMachine
	s.step(1)
	check(idle.state == FactoryNode.State.STARVED, "no input -> STARVED")

func test_splitter() -> void:
	print("splitter")
	var s: FactorySim = track(FactorySim.new(_db()))
	var sp: FactorySplitter = s.add(FactorySplitter.new()) as FactorySplitter
	var a: FactorySink = s.add(FactorySink.new()) as FactorySink
	var b: FactorySink = s.add(FactorySink.new()) as FactorySink
	s.connect_nodes(sp, a)
	s.connect_nodes(sp, b)
	for i: int in 10:
		sp.try_accept(&"ore", null)
		s.step(1)
	check(a.total() == 5 and b.total() == 5, "alternates 5/5")
	a.accepts = [&"none"] as Array[StringName]
	for i: int in 4:
		sp.try_accept(&"ore", null)
		s.step(1)
	check(b.total() == 9, "blocked output -> falls back to the other")

func test_merger() -> void:
	print("merger")
	var s: FactorySim = track(FactorySim.new(_db()))
	var a: FactorySource = s.add(FactorySource.new()) as FactorySource
	var b: FactorySource = s.add(FactorySource.new()) as FactorySource
	a.item = &"ore"; b.item = &"plate"
	a.interval_ticks = 1; b.interval_ticks = 1
	var m: FactoryMerger = s.add(FactoryMerger.new()) as FactoryMerger
	var out: FactorySink = s.add(FactorySink.new()) as FactorySink
	out.rate_limit_ticks = 3
	s.connect_nodes(a, m)
	s.connect_nodes(b, m)
	s.connect_nodes(m, out)
	s.step(600)
	var ra: int = out.received.get(&"ore", 0)
	var rb: int = out.received.get(&"plate", 0)
	check(ra + rb >= 140 and absi(ra - rb) <= 1, "saturated inputs share output fairly (%d / %d)" % [ra, rb])

func test_power_stub() -> void:
	print("power stub (always full power)")
	var db: FactoryDB = _db()
	var s: FactorySim = track(FactorySim.new(db))
	var m: FactoryMachine = s.add(FactoryMachine.new(db.recipes[&"smelt_plate"])) as FactoryMachine
	m.try_accept(&"ore", null)
	s.step(61)
	check(s.power.satisfaction_permille == 1000 and not s.power.brownout, "no generators needed: satisfaction stays 1000")
	check(m.crafts_done == 1 and m.state != FactoryNode.State.NO_POWER, "machine crafts at full speed without power (%d)" % m.crafts_done)
	check(s.power.demand_w == 0 or s.power.demand_w == s.power.supply_w, "demand is reported but never limited")
	var seen: Array[bool] = [false]
	s.power.brownout_changed.connect(func(_on: bool) -> void: seen[0] = true)
	s.step(100)
	check(not seen[0], "brownout_changed never fires in Lite")

func test_chain() -> void:
	print("example production chain")
	var c: ProductionChain = _chain()
	c.sim.step(60 * 60)
	check(c.plate_sink.total() > 0 and c.gear_sink.total() > 0, "chain makes plates (%d) and gears (%d)" % [c.plate_sink.total(), c.gear_sink.total()])
	check(c.sim.power.satisfaction_permille == 1000, "chain runs at full power")
	var r: Array[Dictionary] = c.sim.report()
	check(r.size() == c.sim.nodes.size() and float(r[c.smelter.id]["working"]) > 0.5, "report(): smelter busy > 50%% (%.2f)" % float(r[c.smelter.id]["working"]))

func _chain_json(c: ProductionChain) -> String:
	return JSON.stringify(c.sim.to_save())

func test_determinism_and_save() -> void:
	print("determinism + save/load")
	var a: ProductionChain = _chain()
	var b: ProductionChain = _chain()
	a.sim.step(2500)
	b.sim.step(2500)
	check(_chain_json(a) == _chain_json(b), "two identical runs give identical state")
	var snap: String = _chain_json(a)
	var loaded: FactorySim = track(FactorySim.new(_db()))
	check(loaded.load_save(JSON.parse_string(snap)), "load_save succeeds")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(loaded.to_save()))) == JSON.stringify(JSON.parse_string(snap)), "loaded state re-saves identically")
	a.sim.step(1500)
	loaded.step(1500)
	check(JSON.stringify(loaded.to_save()) == _chain_json(a), "continuing after load matches uninterrupted run")
	var belts_with_items: int = 0
	for n: FactoryNode in loaded.nodes:
		if n is FactoryBelt and (n as FactoryBelt).item_count() > 0:
			belts_with_items += 1
	check(belts_with_items > 0, "save contained items on belts (%d belts)" % belts_with_items)
	check(not loaded.load_save({"format": "x"}) and not loaded.load_save({"format": FactorySim.SAVE_FORMAT, "version": 99}), "bad format/version rejected")

func test_save_file() -> void:
	print("save file")
	var c: ProductionChain = _chain()
	c.sim.step(300)
	check(c.sim.save_file("user://factory_test.json") == OK, "save_file OK")
	var s: FactorySim = track(FactorySim.new(_db()))
	check(s.load_file("user://factory_test.json") == OK and s.tick_count == 300 and s.nodes.size() == c.sim.nodes.size(), "load_file restores tick + nodes")
	check(s.load_file("user://missing.json") == ERR_FILE_NOT_FOUND, "missing file reported")

func test_save_version() -> void:
	print("save version (Lite reads current only)")
	var c: ProductionChain = _chain()
	c.sim.step(200)
	var d: Dictionary = c.sim.to_save()
	check(int(d["version"]) == FactorySim.SAVE_VERSION and str(d["format"]) == FactorySim.SAVE_FORMAT, "saves carry format + version (Pro can load them)")
	var s: FactorySim = track(FactorySim.new(_db()))
	var old: Dictionary = d.duplicate(true)
	old["version"] = 1
	check(not s.load_save(old) and s.last_error.contains("not supported"), "older save versions are refused with a clear error")
	var gen: Dictionary = d.duplicate(true)
	(gen["nodes"] as Array).append({"id": 999, "kind": "generator", "outputs": [], "state": {}})
	check(not s.load_save(gen) and s.last_error.contains("unknown node kind"), "Pro-only node kinds are refused")
	var keys: Array[String] = []
	for e: Variant in d["nodes"]:
		keys.append_array(((e as Dictionary)["state"] as Dictionary).keys())
	check(not keys.has("tunnel") and not keys.has("filter_item") and not keys.has("speed_permille"), "no Pro-only fields in Lite saves")
	if OS.get_environment("WRITE_LITE_FIXTURE") != "":
		var f: FileAccess = FileAccess.open(OS.get_environment("WRITE_LITE_FIXTURE"), FileAccess.WRITE)
		f.store_string(JSON.stringify(d, "\t"))
		f.close()

func test_json_content() -> void:
	print("JSON content")
	var db: FactoryDB = FactoryDB.new()
	check(db.load_json("res://examples/data/content.json") == 10, "content.json loads 3 items, 2 recipes, 5 buildables")
	check(db.validate().is_empty(), "content validates %s" % [db.validate()])
	check(db.buildables[&"smelter"].recipe_options() == ([&"smelt_plate"] as Array[StringName]), "machine buildable has one recipe in Lite")
	var c: ProductionChain = ProductionChain.build(db)
	track(c.sim)
	c.sim.step(3600)
	check(c.gear_sink.total() > 0, "the example chain runs on JSON content (%d gears)" % c.gear_sink.total())

func test_lite_scope() -> void:
	print("Lite scope (no Pro modules)")
	var bad: Array[String] = []
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		var n: String = str(cls["class"])
		if n in ["FactoryBuilder", "FactoryBuildMode", "FactoryHotbar", "FactoryBlueprint", "FactoryGenerator"]:
			bad.append(n)
	check(bad.is_empty(), "no Pro classes in the Lite project %s" % [bad])
	check(not FactorySim.KINDS.has(&"generator"), "no generator node kind")
	check(not FactorySim.new().has_method("bottlenecks"), "no bottleneck finder (Pro)")

func test_view_scene() -> void:
	print("example view scene")
	var d: Node = (load("res://examples/lite_view.tscn") as PackedScene).instantiate()
	root.add_child(d)
	for i: int in 10:
		await physics_frame
	var s: FactorySim = d.get("sim")
	check(s != null and s.tick_count > 0, "lite_view runs the chain in real time (%d ticks)" % s.tick_count)
	check((d.get("view") as FactoryView).sim == s, "debug view draws the sim")
	d.queue_free()
	await process_frame

func test_demo() -> void:
	print("CC0 sprite demo")
	const Demo = preload("res://examples/demo.gd")
	var db: FactoryDB = ProductionChain.default_db()
	var m: FactoryMachine = FactoryMachine.new(db.recipes[&"smelt_plate"])
	check(Demo.sprite_for(m, 0) == "smelt_off", "idle smelter uses the off sprite")
	m.state = FactoryNode.State.WORKING
	check(Demo.sprite_for(m, 8) == "smelt_1" and Demo.sprite_for(m, 16) == "smelt_2", "working smelter animates")
	var p: FactoryMachine = FactoryMachine.new(db.recipes[&"press_gear"])
	check(Demo.sprite_for(p, 0) == "press_0", "press has its own sprite")
	var c: ProductionChain = ProductionChain.build(db)
	track(c.sim)
	var routes: Dictionary = {}
	for n: FactoryNode in c.sim.nodes:
		if n is FactoryBelt:
			routes[[n.inputs[0], n.outputs[0]]] = Demo.belt_route(n as FactoryBelt)
	check(routes[[c.splitter, c.plate_sink]] == ([Vector2i(10, 3), Vector2i(10, 1), Vector2i(13, 1)] as Array[Vector2i]), "splitter outputs turn first")
	check(routes[[c.src_a, c.merger]] == ([Vector2i(1, 1), Vector2i(4, 1), Vector2i(4, 3)] as Array[Vector2i]), "source belts run horizontal first")
	check(routes[[c.merger, c.smelter]].size() == 2, "straight belt has no corner")
	var pts: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2)]
	check(Demo.route_point(pts, 0.0) == Vector2(0.5, 0.5) and Demo.route_point(pts, 0.5) == Vector2(2.5, 0.5) and Demo.route_point(pts, 1.0) == Vector2(2.5, 2.5), "route_point walks the L by distance")
	var missing: Array[String] = []
	for tick: int in [0, 8, 16, 24]:
		for n: FactoryNode in c.sim.nodes:
			for st: int in [FactoryNode.State.IDLE, FactoryNode.State.WORKING]:
				n.state = st as FactoryNode.State
				var nm: String = Demo.sprite_for(n, tick) if not n is FactoryBelt else "belt_%d" % (tick % 4)
				if not ResourceLoader.exists(Demo.SPR % nm):
					missing.append(nm)
	for it: String in ["ore", "plate", "gear"]:
		if not ResourceLoader.exists(Demo.SPR % ("item_" + it)):
			missing.append(it)
	check(missing.is_empty(), "every sprite the demo draws is shipped %s" % [missing])
	for f: String in ["res://assets/sources/kenney_sci-fi-sounds-License.txt", "res://assets/sources/kenney_interface-sounds-License.txt", "res://assets/sources/kenney_fonts-License.txt", "res://assets/sources/original-sprites-CC0.txt"]:
		check(FileAccess.file_exists(f), "licence file " + f.get_file())
	var d: Node = (load("res://examples/demo.tscn") as PackedScene).instantiate()
	root.add_child(d)
	for i: int in 10:
		await physics_frame
	var s: FactorySim = d.get("sim")
	check(s.tick_count > 0, "demo runs the chain in real time (%d ticks)" % s.tick_count)
	d.call("set_speed", 2)
	check(is_equal_approx((d.get("runner") as FactorySimNode).time_scale, 4.0), "key 3 = x4 speed")
	d.call("toggle_pause")
	var t0: int = s.tick_count
	for i: int in 5:
		await physics_frame
	check(s.tick_count == t0 and (d.get("runner") as FactorySimNode).time_scale == 0.0, "space pauses the sim")
	d.call("toggle_pause")
	s.step(7200)
	await process_frame
	await process_frame
	check(int(d.get("chimes")) > 0, "a gear arriving rings the sfx counter (%d chimes, %d gears)" % [int(d.get("chimes")), (d.get("chain") as ProductionChain).gear_sink.total()])
	d.call("restart")
	check((d.get("sim") as FactorySim).tick_count == 0 and d.get("sim") != s, "R restarts with a fresh sim")
	await physics_frame
	d.queue_free()
	await process_frame

