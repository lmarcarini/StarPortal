class_name ConstraintList
extends VBoxContainer
## The Address Workbench draft's constraints, one row each in plain words with a remove
## button, and "clear all", which asks for confirmation first. Reports requests; never edits
## the draft.
## Bible: gate-and-address-spec.md#player-tools

## The player asked to remove the constraint at [param index].
signal remove_requested(index: int)
## The player confirmed removing every constraint.
signal clear_confirmed

const _ROW_SCENE: PackedScene = preload("res://src/ui/analysis/workbench/constraint_row.tscn")

@onready var _rows: VBoxContainer = %Rows
@onready var _empty: Label = %Empty
@onready var _clear_button: Button = %ClearAll
@onready var _dialog: ConfirmationDialog = %ClearDialog


func _ready() -> void:
	_clear_button.pressed.connect(_dialog.popup_centered)
	_dialog.confirmed.connect(clear_confirmed.emit)
	_translate_dialog()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate_dialog()


## Shows one row per constraint in [param constraints], in order. When a row had focus, the
## row now at its place (or "clear all") takes it, so keyboard and gamepad focus is not lost.
func show_constraints(constraints: Array[AddressConstraint]) -> void:
	var focused_row: int = _focused_row()
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for position: int in constraints.size():
		var row: ConstraintRow = _ROW_SCENE.instantiate() as ConstraintRow
		_rows.add_child(row)
		row.show_constraint(position, constraints[position])
		row.remove_pressed.connect(remove_requested.emit)
	_empty.visible = constraints.is_empty()
	_clear_button.disabled = constraints.is_empty()
	if focused_row >= 0:
		_restore_focus(focused_row)


## Returns the rows, in draft order.
func get_rows() -> Array[ConstraintRow]:
	var rows: Array[ConstraintRow] = []
	for child: Node in _rows.get_children():
		rows.append(child as ConstraintRow)
	return rows


## Returns the "clear all" button.
func get_clear_button() -> Button:
	return _clear_button


## Returns the confirmation dialog "clear all" opens.
func get_clear_dialog() -> ConfirmationDialog:
	return _dialog


func _focused_row() -> int:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused == null or not _rows.is_ancestor_of(focused):
		return -1
	var rows: Array[ConstraintRow] = get_rows()
	for position: int in rows.size():
		if rows[position].is_ancestor_of(focused):
			return position
	return -1


func _restore_focus(position: int) -> void:
	var rows: Array[ConstraintRow] = get_rows()
	if rows.is_empty():
		_clear_button.grab_focus()
		return
	rows[mini(position, rows.size() - 1)].get_remove_button().grab_focus()


func _translate_dialog() -> void:
	_dialog.title = tr("WORKBENCH_CLEAR_TITLE")
	_dialog.dialog_text = tr("WORKBENCH_CLEAR_QUESTION")
	_dialog.ok_button_text = tr("WORKBENCH_CLEAR_YES")
	_dialog.cancel_button_text = tr("WORKBENCH_CLEAR_NO")
