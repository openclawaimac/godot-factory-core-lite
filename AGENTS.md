# AGENTS.md: Factory Core Lite
- Godot 4.7.2, typed GDScript (untyped declarations are errors). Run `godot --headless --import` after adding a class_name.
- Tests: `tools/run_tests.sh /path/to/godot` must print `RESULT: PASS` and exit 0. Add a section in `tests/run_tests.gd` (`await H.section("test_x", test_x)`) and update `tests/expected.json`.
- The sim is integer and deterministic: no floats or frame delta in sim state. Call `sim.dispose()` when done.
- Content is data (`examples/data/content.json` or `data/*.tres`), not new classes.
- Keep the API identical to Factory Core Pro so projects can upgrade without code changes.
