class_name StateMachine
extends RefCounted
## Minimal finite state machine. The owner registers states, calls
## `start()`, then `update(delta)` at whatever rate it wants. Transitions
## requested during an update are applied immediately (exit → enter).

signal state_changed(from: StringName, to: StringName)

var actor: Node

var _states: Dictionary = {}
var _current: State
var _current_name: StringName = &""


func _init(p_actor: Node = null) -> void:
	actor = p_actor


## Registers a state under `state_name`. Returns the state for chaining.
func add(state_name: StringName, state: State) -> State:
	state.machine = self
	state.actor = actor
	_states[state_name] = state
	return state


## Enters the first state.
func start(state_name: StringName) -> void:
	assert(_states.has(state_name), "Unknown state: %s" % state_name)
	_current_name = state_name
	_current = _states[state_name]
	_current.enter(&"")
	state_changed.emit(&"", state_name)


## Switches state. Re-entering the current state is ignored.
func change(state_name: StringName) -> void:
	assert(_states.has(state_name), "Unknown state: %s" % state_name)
	if state_name == _current_name:
		return
	var previous: StringName = _current_name
	if _current != null:
		_current.exit(state_name)
	_current_name = state_name
	_current = _states[state_name]
	_current.enter(previous)
	state_changed.emit(previous, state_name)


## Ticks the current state.
func update(delta: float) -> void:
	if _current != null:
		_current.update(delta)


func get_current() -> StringName:
	return _current_name


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)
