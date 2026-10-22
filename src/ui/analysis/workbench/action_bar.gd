class_name ActionBar
extends HFlowContainer
## The Address Workbench's actions on the picked glyph: rule out, not at a seal, in the
## address, nearer than another, group seven as a set, and cancel. The buttons wrap onto more
## lines when the text is long. Reports the action; never edits the draft.
## Bible: gate-and-address-spec.md#player-tools

## The player pressed [param action].
signal action_chosen(action: Action)

## The actions, one button each.
enum Action { RULE_OUT, NOT_AT, INCLUDE, NEARER, GROUP, CANCEL }

@onready var _buttons: Dictionary[Action, Button] = {
	Action.RULE_OUT: %RuleOut,
	Action.NOT_AT: %NotAt,
	Action.INCLUDE: %Include,
	Action.NEARER: %Nearer,
	Action.GROUP: %Group,
	Action.CANCEL: %Cancel,
}


func _ready() -> void:
	for action: Action in _buttons:
		_buttons[action].pressed.connect(action_chosen.emit.bind(action))


## Enables the glyph actions when [param mode] has a picked glyph and is not waiting for a
## second choice, grouping when [param can_group], and cancel whenever something is picked.
func show_state(mode: WorkbenchPicker.Mode, can_group: bool) -> void:
	var is_picked: bool = mode == WorkbenchPicker.Mode.GLYPH_PICKED
	for action: Action in [Action.RULE_OUT, Action.NOT_AT, Action.INCLUDE, Action.NEARER]:
		_buttons[action].disabled = not is_picked
	_buttons[Action.GROUP].disabled = not can_group
	_buttons[Action.CANCEL].disabled = mode == WorkbenchPicker.Mode.IDLE


## Returns the button of [param action].
func get_button(action: Action) -> Button:
	return _buttons[action]
