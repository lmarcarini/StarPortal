class_name DebugOverlay
extends PanelContainer
## Debug-only panel: the speed index, the ticks run over the last second, the mean tick time
## and a collapsible tree of simulation.state.to_dict(). Hidden at start; the
## debug_toggle_overlay action shows and hides it. The shell creates it only in debug builds.
## It reads SimClock.simulation and never changes it.
## A tick's time runs from the previous tick in the same frame, or from the start of the
## frame for the first one, to its EventBus.tick_advanced; it includes the tick's listeners.
## Bible: technical-architecture.md#architecture-overview

## Seconds between refreshes; the state tree is updated at most this often.
const REFRESH_SECONDS: float = 0.5
## Refresh windows that make up the last second.
const WINDOWS_PER_SECOND: int = 2

const _ACTION_TOGGLE: StringName = &"debug_toggle_overlay"
const _USEC_PER_MSEC: float = 1000.0

## Ticks run over the last second, as of the last refresh.
var ticks_per_second: int = 0
## Mean tick time over the last second in milliseconds, as of the last refresh.
var mean_tick_msec: float = 0.0

var _window_ticks: Array[int] = []
var _window_usec: Array[int] = []
var _mark_usec: int = 0
var _items: Dictionary[String, TreeItem] = {}

@onready var _speed_label: Label = %SpeedIndexLabel
@onready var _rate_label: Label = %TicksPerSecondLabel
@onready var _tick_time_label: Label = %TickTimeLabel
@onready var _tree: Tree = %StateTree
@onready var _refresh_timer: Timer = %RefreshTimer


func _ready() -> void:
	visible = false
	_window_ticks.resize(WINDOWS_PER_SECOND)
	_window_usec.resize(WINDOWS_PER_SECOND)
	_tree.create_item()
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.speed_changed.connect(_on_speed_changed)
	get_tree().process_frame.connect(_on_process_frame)
	_refresh_timer.timeout.connect(_on_refresh_timeout)
	_refresh_timer.start(REFRESH_SECONDS)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(_ACTION_TOGGLE):
		return
	get_viewport().set_input_as_handled()
	toggle()


## Shows the overlay if hidden, hides it if shown. Showing it redraws the labels at once;
## the state tree is built at once only the first time, then follows the refresh timer.
func toggle() -> void:
	visible = not visible
	if not visible:
		return
	_show_labels()
	if _items.is_empty():
		_refresh_tree()


func _show_labels() -> void:
	_show_speed_index()
	_rate_label.text = tr("UI_DEBUG_TICKS_PER_SECOND").format({"rate": ticks_per_second})
	_tick_time_label.text = tr("UI_DEBUG_MEAN_TICK_TIME").format({"ms": "%.3f" % mean_tick_msec})


func _show_speed_index() -> void:
	var index: String = "-"
	if SimClock.simulation != null:
		index = str(SimClock.simulation.state.clock.speed_index)
	_speed_label.text = tr("UI_DEBUG_SPEED_INDEX").format({"index": index})


func _on_process_frame() -> void:
	_mark_usec = Time.get_ticks_usec()


func _on_tick_advanced(_tick: int) -> void:
	var now: int = Time.get_ticks_usec()
	var last: int = WINDOWS_PER_SECOND - 1
	_window_ticks[last] += 1
	_window_usec[last] += now - _mark_usec
	_mark_usec = now


func _on_speed_changed(_speed_index: int) -> void:
	if visible:
		_show_speed_index()


func _on_refresh_timeout() -> void:
	var ticks: int = 0
	var usec: int = 0
	for window: int in WINDOWS_PER_SECOND:
		ticks += _window_ticks[window]
		usec += _window_usec[window]
	ticks_per_second = ticks
	mean_tick_msec = 0.0 if ticks == 0 else usec / _USEC_PER_MSEC / ticks
	_window_ticks.pop_front()
	_window_ticks.append(0)
	_window_usec.pop_front()
	_window_usec.append(0)
	if visible:
		_show_labels()
		_refresh_tree()


## Updates the state tree in place, so collapsed branches stay collapsed.
func _refresh_tree() -> void:
	var seen: Dictionary[String, bool] = {}
	if SimClock.simulation != null:
		_fill(_tree.get_root(), SimClock.simulation.state.to_dict(), "", seen)
	_drop_unseen(seen)


## Adds or updates one item per key of [param data] under [param parent], recursively.
func _fill(
	parent: TreeItem, data: Dictionary, path: String, seen: Dictionary[String, bool]
) -> void:
	var keys: Array = data.keys()
	keys.sort()
	for key: Variant in keys:
		var child_path: String = "%s/%s" % [path, key]
		seen[child_path] = true
		var item: TreeItem = _item_at(parent, child_path, str(key))
		var value: Variant = data[key]
		if value is Array:
			var values: Array = value
			value = _array_as_dict(values)
		if value is Dictionary:
			var branch: Dictionary = value
			item.set_text(1, "")
			_fill(item, branch, child_path, seen)
		else:
			item.set_text(1, str(value))


func _item_at(parent: TreeItem, path: String, label: String) -> TreeItem:
	if _items.has(path):
		return _items[path]
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, label)
	_items[path] = item
	return item


## Frees items whose path is no longer in the state. Parents sort before their children,
## and freeing a parent frees its children, so freed children are skipped.
func _drop_unseen(seen: Dictionary[String, bool]) -> void:
	var stale: Array[String] = []
	for path: String in _items:
		if not seen.has(path):
			stale.append(path)
	stale.sort()
	for path: String in stale:
		var item: TreeItem = _items[path]
		_items.erase(path)
		if is_instance_valid(item):
			item.free()


static func _array_as_dict(values: Array) -> Dictionary:
	var data: Dictionary = {}
	for index: int in values.size():
		data[index] = values[index]
	return data
