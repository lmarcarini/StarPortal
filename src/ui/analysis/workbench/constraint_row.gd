class_name ConstraintRow
extends HBoxContainer
## One constraint of the Address Workbench draft in plain words, with a remove button.
## Bible: gate-and-address-spec.md#player-tools

## The player pressed remove on the row showing [param constraint].
signal remove_pressed(constraint: AddressConstraint)

var _constraint: AddressConstraint = null

@onready var _text: Label = %Text
@onready var _remove: Button = %Remove


func _ready() -> void:
	_remove.pressed.connect(func() -> void: remove_pressed.emit(_constraint))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


## Shows [param constraint].
func show_constraint(constraint: AddressConstraint) -> void:
	_constraint = constraint
	_refresh_text()


## Returns the sentence shown.
func get_text() -> String:
	return _text.text


## Returns the remove button.
func get_remove_button() -> Button:
	return _remove


func _refresh_text() -> void:
	_text.text = WorkbenchText.describe(_constraint, tr) if _constraint != null else ""
