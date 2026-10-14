# AGENTS.md: Factory Core Lite

## What this is
Factory Core Lite is a free, MIT-licensed **Godot 4 factory / automation starter kit / template** written in typed GDScript for Godot 4.7 (tested on 4.7.2). It provides headless-testable game logic plus a small demo. The paid Pro edition (€16, commercial EULA) has the same API plus more features: https://huginhelm.itch.io/factory-core
Website: https://openclawaimac.github.io/factory-core/

## Structure
- `addons/factory_core/sim/` – FactorySim (deterministic integer fixed-tick sim: step, link, report, to_save/load_save), FactorySimNode, FactoryStats
- `addons/factory_core/nodes/` – belts (two-lane), source, sink, machine, splitter, merger
- `addons/factory_core/data/` – FactoryItem, FactoryRecipe, FactoryBuildable, FactoryDB (Resources or JSON, validate())
- `addons/factory_core/power/, view/` – power grid stub, FactoryView renderer
- `data/` – sample .tres items/recipes/buildables
- `examples/` – demo.tscn (main scene), production_chain.gd, lite_view, data/content.json
- `tests/` – strict headless suite (run_tests.gd, harness.gd, expected.json)
- `tools/` – run_tests.sh, make_release.sh

## Run the tests
```bash
godot --headless --path . --import   # once, after clone or after adding a class_name
bash tools/run_tests.sh /path/to/godot   # or set GODOT=...; must print "RESULT: PASS 65 checks" and exit 0
```
The runner fails on non-zero exit, any `SCRIPT ERROR`, or a missing `RESULT: PASS` line.

## How to extend
- New items/recipes/buildables: add data to `examples/data/content.json` or `data/*.tres` – not new classes.
- New node types: extend `FactoryNode` in `addons/factory_core/nodes/`, keep sim state integer and deterministic (no floats or frame delta).
- Drive the sim from code with `FactorySim.step(n)`; call `sim.dispose()` when done.
- Add tests for new behaviour: a section in `tests/run_tests.gd` (`await H.section("test_x", test_x)`), then update `tests/expected.json`.

## Rules
- Godot 4.7.2, typed GDScript (untyped declarations are errors). Run `godot --headless --import` after adding a class_name.
- Tests: `tools/run_tests.sh /path/to/godot` must print `RESULT: PASS` and exit 0. Add a section in `tests/run_tests.gd` (`await H.section("test_x", test_x)`) and update `tests/expected.json`.
- The sim is integer and deterministic: no floats or frame delta in sim state. Call `sim.dispose()` when done.
- Content is data (`examples/data/content.json` or `data/*.tres`), not new classes.
- Keep the API identical to Factory Core Pro so projects can upgrade without code changes.

## Lite vs Pro
Lite = free, MIT, 65 tests, core systems + minimal demo. Pro = €16, commercial per-seat EULA, 245 tests, full feature set and playable demo, same API. See README.md "Lite vs Pro" or https://openclawaimac.github.io/factory-core/. Get Pro: https://huginhelm.itch.io/factory-core
