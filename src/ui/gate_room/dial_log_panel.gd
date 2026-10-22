class_name DialLogPanel
extends VBoxContainer
## The Dial Log, newest first: every attempt with its date and time, address, outcome and the
## energy it cost. The world's designation appears for a lock only; for any other outcome the
## panel never even reads the entry's world. Reads state only.
## Bible: gate-and-address-spec.md#player-tools

const _ROW_SCENE: PackedScene = preload("res://src/ui/gate_room/log_row.tscn")

var _simulation: Simulation = null
var _rows: Array[LogRow] = []

@onready var _rows_box: VBoxContainer = %Rows
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	_rebuild()


func _enter_tree() -> void:
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


## Connects the panel to [param simulation] and rebuilds the log from its state.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	if is_node_ready():
		_rebuild()


## Returns the rows, newest first.
func get_rows() -> Array[LogRow]:
	return _rows


## Returns the first row, the panel's focus target, or null when the log is empty.
func get_first_focus() -> Control:
	return null if _rows.is_empty() else _rows[0]


func _rebuild() -> void:
	for row: LogRow in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	if _simulation != null:
		_sync()
	_empty_label.visible = _rows.is_empty()


## Adds the rows of the entries that have none yet, each at the top.
func _sync() -> void:
	var log_entries: Array[DialLogEntry] = _simulation.state.gate.dial_log
	for index: int in range(_rows.size(), log_entries.size()):
		var row: LogRow = _ROW_SCENE.instantiate() as LogRow
		row.setup(log_entries[index], _designation_for(log_entries[index]))
		_rows_box.add_child(row)
		_rows_box.move_child(row, 0)
		_rows.push_front(row)
	_empty_label.visible = _rows.is_empty()


## Returns the designation to show for [param entry]: "" unless it is a lock.
func _designation_for(entry: DialLogEntry) -> String:
	if not DialOutcome.is_lock(entry.outcome):
		return ""
	var world: WorldRecord = _simulation.state.galaxy.get_world(entry.world_id)
	if world == null or world.designation.is_empty():
		return tr("GATE_WORMHOLE_UNNAMED")
	return world.designation


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	if _simulation != null and is_node_ready():
		_sync()
