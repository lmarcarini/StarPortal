class_name DialQueuePanel
extends VBoxContainer
## The dial queue: every queued address as a glyph row with the charge it needs and when the
## bank will hold it at the current output. The player selects a row or removes it; the panel
## posts UnqueueAddressCommand and never edits the queue itself. It always keeps one row
## selected while the queue is not empty.
## Bible: gate-and-address-spec.md#player-tools, game-design.md#core-loop

## The selection changed; [param address] is null when the queue is empty.
signal selection_changed(address: GateAddress)

const _ROW_SCENE: PackedScene = preload("res://src/ui/gate_room/queue_row.tscn")

var _simulation: Simulation = null
var _selected_key: String = ""
var _emitted_key: String = ""
var _rows: Array[QueueRow] = []

@onready var _rows_box: VBoxContainer = %Rows
@onready var _empty_label: Label = %EmptyLabel


func _enter_tree() -> void:
	EventBus.dial_queue_changed.connect(_rebuild)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.dial_queue_changed.disconnect(_rebuild)
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the panel to [param simulation] and shows its queue.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_selected_key = ""
	_emitted_key = ""
	_rebuild()


## Selects the row of [param address]. Remembers the choice when the row does not exist yet,
## for the case of a command that applies on the next tick.
func select_address(address: GateAddress) -> void:
	_selected_key = address.key()
	_apply_selection()


## Returns the selected address, or null when the queue is empty.
func get_selected() -> GateAddress:
	for row: QueueRow in _rows:
		if row.get_address().key() == _selected_key:
			return row.get_address()
	return null


## Returns the rows, first in line first.
func get_rows() -> Array[QueueRow]:
	return _rows


## Returns the first row's select button, or null when the queue is empty.
func get_first_focus() -> Control:
	if _rows.is_empty():
		return null
	return _rows[0].get_select_button()


func _rebuild() -> void:
	if _simulation == null or not is_node_ready():
		return
	var focus_index: int = _focused_row_index()
	for row: QueueRow in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	for address: GateAddress in _simulation.state.gate.dial_queue:
		_add_row(address)
	_empty_label.visible = _rows.is_empty()
	_keep_a_selection()
	_refresh()
	_restore_focus(focus_index)


func _add_row(address: GateAddress) -> void:
	var row: QueueRow = _ROW_SCENE.instantiate() as QueueRow
	row.setup(address)
	row.selected.connect(select_address)
	row.remove_requested.connect(_on_remove_requested)
	_rows_box.add_child(row)
	_rows.append(row)


## Keeps the selection when its row still exists; otherwise selects the first row.
func _keep_a_selection() -> void:
	var found: bool = false
	for row: QueueRow in _rows:
		found = found or row.get_address().key() == _selected_key
	if not found:
		_selected_key = "" if _rows.is_empty() else _rows[0].get_address().key()
	_apply_selection()


## Marks the selected row and posts [signal selection_changed] when the selected address
## differs from the last one posted.
func _apply_selection() -> void:
	for row: QueueRow in _rows:
		row.set_selected(row.get_address().key() == _selected_key)
	var selected: GateAddress = get_selected()
	var key: String = "" if selected == null else selected.key()
	if key == _emitted_key:
		return
	_emitted_key = key
	selection_changed.emit(selected)


func _refresh() -> void:
	if _simulation == null or not is_node_ready():
		return
	for row: QueueRow in _rows:
		row.refresh(_simulation.state)


## Index of the row that holds the keyboard / gamepad focus, or -1.
func _focused_row_index() -> int:
	var owner_control: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_control == null:
		return -1
	for index: int in _rows.size():
		if _rows[index].is_ancestor_of(owner_control):
			return index
	return -1


func _restore_focus(index: int) -> void:
	if index < 0 or _rows.is_empty():
		return
	_rows[mini(index, _rows.size() - 1)].get_select_button().grab_focus()


func _on_remove_requested(address: GateAddress) -> void:
	if _simulation != null:
		_simulation.submit(UnqueueAddressCommand.create(address))


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_dial_started(_address_key: String) -> void:
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_refresh()
