class_name FactoryStats
extends RefCounted
## Rolling per-node statistics over the last `window` ticks: state ratios and
## items out. Ring buffers, O(1) per tick.

var window: int
var _states: PackedByteArray
var _outs: PackedInt32Array
var _i: int = 0
var _filled: int = 0
var _out_this_tick: int = 0
## Lifetime totals.
var total_out: int = 0
var total_in: int = 0

func _init(p_window: int = 600) -> void:
	window = p_window
	_states.resize(window)
	_outs.resize(window)

func note_in() -> void:
	total_in += 1

func note_out() -> void:
	_out_this_tick += 1
	total_out += 1

## Called once per tick by FactorySim with the node's state for that tick.
func record(state: int) -> void:
	_states[_i] = state
	_outs[_i] = _out_this_tick
	_out_this_tick = 0
	_i = (_i + 1) % window
	_filled = mini(_filled + 1, window)

## Fraction (0..1) of recorded ticks spent in `state`.
func ratio(state: int) -> float:
	if _filled == 0:
		return 0.0
	var n: int = 0
	for k: int in _filled:
		if _states[k] == state:
			n += 1
	return float(n) / _filled

## Items output per minute over the window.
func per_minute(ticks_per_second: int) -> float:
	if _filled == 0:
		return 0.0
	var s: int = 0
	for k: int in _filled:
		s += _outs[k]
	return float(s) * ticks_per_second * 60.0 / _filled
