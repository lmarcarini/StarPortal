class_name WireAction
extends RefCounted
## One key on a wire card: an icon, a hover help and what it does: a command to submit (the
## same one the old screens sent), a screen to go to, or a special step the shell runs
## (&"rescue", &"report", &"dismiss"). Built by WireRules; never saved.
## Bible: docs/content/interface-rethink.md section 6

## Key id (stable, for tests and focus).
var id: StringName = &""
## HardwareIcons id.
var icon_id: StringName = &""
## Hover help: a translation key or already translated text.
var help: String = ""
## The command to submit, or null.
var command: Command = null
## Where to go when there is no command; &"" for none.
var view_id: StringName = &""
var sub_tab: StringName = &""
## A step the shell runs: &"rescue", &"report", &"dismiss" or &"".
var special: StringName = &""


## A key that submits [param cmd].
static func submit(key: StringName, icon: StringName, hint: String, cmd: Command) -> WireAction:
	var action: WireAction = _make(key, icon, hint)
	action.command = cmd
	return action


## A key that opens [param view] on [param tab].
static func go(
	key: StringName, icon: StringName, view: StringName, tab: StringName = &""
) -> WireAction:
	var action: WireAction = _make(key, icon, "WIRE_KEY_" + String(key).to_upper())
	action.view_id = view
	action.sub_tab = tab
	return action


## A key the shell handles ([param step]).
static func step(key: StringName, icon: StringName, step_id: StringName) -> WireAction:
	var action: WireAction = _make(key, icon, "WIRE_KEY_" + String(key).to_upper())
	action.special = step_id
	return action


## Why the key is refused in [param state] (the command's refusal code), or &"".
func refusal(state: GameState) -> StringName:
	if command == null:
		return &""
	var result: CommandResult = command.validate(state)
	return &"" if result.is_ok else result.error_code


static func _make(key: StringName, icon: StringName, hint: String) -> WireAction:
	var action: WireAction = WireAction.new()
	action.id = key
	action.icon_id = icon
	action.help = hint
	return action
