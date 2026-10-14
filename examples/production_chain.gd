class_name ProductionChain
extends RefCounted
## Builds the example chain used by the demo and tests:
##   2 ore sources -> belts -> merger -> belt -> smelter (ore->plate)
##   -> belt -> splitter -> belt -> plate sink
##                       -> belt -> press (2 plate->gear) -> belt -> gear sink
## Lite: machines are always fully powered (FactoryPowerGrid stub). Pro adds
## generators and brownout.

var sim: FactorySim
var src_a: FactorySource
var src_b: FactorySource
var merger: FactoryMerger
var smelter: FactoryMachine
var splitter: FactorySplitter
var press: FactoryMachine
var plate_sink: FactorySink
var gear_sink: FactorySink

static func build(db: FactoryDB) -> ProductionChain:
	var c: ProductionChain = ProductionChain.new()
	var s: FactorySim = FactorySim.new(db)
	c.sim = s
	c.src_a = s.add(FactorySource.new(), Vector2i(1, 1)) as FactorySource
	c.src_b = s.add(FactorySource.new(), Vector2i(1, 5)) as FactorySource
	for src: FactorySource in [c.src_a, c.src_b]:
		src.item = &"ore"
		src.interval_ticks = 40
		src.power_w = 50
	c.merger = s.add(FactoryMerger.new(), Vector2i(4, 3)) as FactoryMerger
	c.smelter = s.add(FactoryMachine.new(db.recipes[&"smelt_plate"]), Vector2i(7, 3)) as FactoryMachine
	c.splitter = s.add(FactorySplitter.new(), Vector2i(10, 3)) as FactorySplitter
	c.plate_sink = s.add(FactorySink.new(), Vector2i(13, 1)) as FactorySink
	c.press = s.add(FactoryMachine.new(db.recipes[&"press_gear"]), Vector2i(13, 5)) as FactoryMachine
	c.gear_sink = s.add(FactorySink.new(), Vector2i(16, 5)) as FactorySink
	s.link(c.src_a, c.merger, 3)
	s.link(c.src_b, c.merger, 3)
	s.link(c.merger, c.smelter, 3)
	s.link(c.smelter, c.splitter, 3)
	s.link(c.splitter, c.plate_sink, 3)
	s.link(c.splitter, c.press, 3)
	s.link(c.press, c.gear_sink, 3)
	return c

static func default_db() -> FactoryDB:
	var db: FactoryDB = FactoryDB.new()
	db.load_dir("res://data")
	return db
