extends Node2D
## Lite example scene: the example production chain running in real time,
## drawn by the debug/fallback FactoryView (colour = node state).
## Run: godot --path . (main scene). Headless: see tests/run_tests.gd.

var sim: FactorySim
var view: FactoryView
var runner: FactorySimNode
var label: Label
var chain: ProductionChain

func _ready() -> void:
	chain = ProductionChain.build(ProductionChain.default_db())
	sim = chain.sim
	runner = FactorySimNode.new()
	runner.sim = sim
	add_child(runner)
	view = FactoryView.new()
	view.sim = sim
	view.cell_px = 48.0
	view.position = Vector2(200, 160)
	add_child(view)
	label = Label.new()
	label.position = Vector2(24, 20)
	add_child(label)

func _process(_delta: float) -> void:
	label.text = "Factory Core Lite  |  tick %d  |  plates %d  gears %d  |  grey idle, green working, yellow starved, orange blocked" % [sim.tick_count, chain.plate_sink.total(), chain.gear_sink.total()]

func _exit_tree() -> void:
	sim.dispose()
