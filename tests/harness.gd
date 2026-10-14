extends RefCounted
## Strict test harness shared by tests/run_tests.gd. A run FAILS (exit 1) when:
## - any check fails,
## - any SCRIPT ERROR (or other engine error) is logged while tests run; a GDScript
##   runtime error aborts the test function silently, so this is the only way to see it,
## - a test section does not run to its end (aborted function / missing await),
## - the number of completed sections or checks differs from tests/expected.json.
## The last stdout line is always "RESULT: PASS ..." or "RESULT: FAIL ...";
## tools/run_tests.sh also fails if that line is missing (crash / early exit).
## Self-test: HARNESS_SELFTEST=crash adds a section that crashes on purpose.

class ErrorCounter extends Logger:
	var script_errors: int = 0
	var other_errors: int = 0
	var messages: Array[String] = []
	var _mutex: Mutex = Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			script_errors += 1
		else:
			other_errors += 1
		if messages.size() < 20:
			messages.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass

var errors: ErrorCounter = ErrorCounter.new()
var checks: int = 0
var failures: int = 0
var sections_started: int = 0
var sections_done: int = 0
var problems: Array[String] = []
## Engine errors that tests trigger on purpose (substring of the message); not counted.
var allowed_errors: Array[String] = []
var _expected_path: String

func _init(expected_path: String = "res://tests/expected.json") -> void:
	_expected_path = expected_path
	OS.add_logger(errors)

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  PASS ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _errors_now() -> int:
	return errors.script_errors + errors.other_errors

## Runs one test function (sync or async). Fails the section if it logs an error
## or never reaches its end.
func section(name: String, fn: Callable) -> void:
	sections_started += 1
	var e0: int = _errors_now()
	var m0: int = errors.messages.size()
	await fn.call()
	sections_done += 1
	var new_msgs: Array[String] = errors.messages.slice(m0)
	var unexpected: int = _errors_now() - e0
	for m: String in new_msgs:
		for a: String in allowed_errors:
			if m.contains(a):
				unexpected -= 1
				break
	if unexpected > 0:
		problems.append("section '%s' logged %d error(s): %s" % [name, unexpected, new_msgs])
		printerr("  FAIL section '%s' logged %d script/engine error(s)" % [name, unexpected])

## Prints the verdict and returns the exit code.
func finish() -> int:
	var exp: Dictionary = {}
	var f: FileAccess = FileAccess.open(_expected_path, FileAccess.READ)
	if f:
		var v: Variant = JSON.parse_string(f.get_as_text())
		if v is Dictionary:
			exp = v
	if exp.is_empty():
		problems.append("missing or unreadable %s" % _expected_path)
	else:
		if int(exp.get("sections", -1)) != sections_done:
			problems.append("sections: expected %d, completed %d" % [int(exp.get("sections", -1)), sections_done])
		if int(exp.get("checks", -1)) != checks:
			problems.append("checks: expected %d, ran %d (update tests/expected.json when adding tests)" % [int(exp.get("checks", -1)), checks])
	if sections_done != sections_started:
		problems.append("%d section(s) never finished" % (sections_started - sections_done))
	print("%d checks, %d failures" % [checks, failures])
	for p: String in problems:
		printerr("  PROBLEM ", p)
	var ok: bool = failures == 0 and problems.is_empty()
	print("RESULT: %s %d checks, %d failures, %d sections, %d script errors, %d problems" % ["PASS" if ok else "FAIL", checks, failures, sections_done, errors.script_errors, problems.size()])
	return 0 if ok else 1

## Deliberate crash used by the harness self-test (HARNESS_SELFTEST=crash).
func crash_selftest() -> void:
	check(true, "self-test section starts")
	var n: Variant = null
	n.this_method_does_not_exist()
	check(true, "never reached")

static func selftest_mode() -> String:
	return OS.get_environment("HARNESS_SELFTEST")
