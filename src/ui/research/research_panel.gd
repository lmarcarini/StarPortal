class_name ResearchPanel
extends VBoxContainer
## The SELECTED panel of the Research tab (docs/content/m25-lean-start.md section 3): the
## focused project's name, cost and time at the current staffing, its line, and Start, or
## Cancel with the refund shown while it runs. Start is greyed with the reason when
## ResearchRules.can_start refuses. A done project shows "done ✓"; a locked slot shows its
## reason and no button. The panel only emits [signal action_pressed]; the view submits the command.
## Bible: docs/content/m25-lean-start.md section 3

## Emitted when Start or Cancel is pressed for [param project_id].
signal action_pressed(project_id: StringName)

var _heading: Label = _add_label(16)
var _name: Label = _add_label(22)
var _cost: Label = _add_label(16)
var _line: Label = _add_label(16)
var _button: Button = _add_button()
var _reason: Label = _add_label(14)
var _project: StringName = &""


## Shows [param def] as it stands in [param state]; null shows only the heading.
func show_project(state: GameState, def: ResearchDef) -> void:
	_heading.text = tr(&"RESEARCH_SELECTED")
	_project = &"" if def == null else def.id
	for label: Label in [_name, _cost, _line, _reason]:
		label.text = ""
	_button.visible = false
	if def == null:
		return
	_name.text = tr(def.name_key)
	_line.text = tr(def.line_key)
	if def.is_locked():
		return
	_cost.text = (
		tr(&"RESEARCH_PANEL_COST")
		. format(
			{
				"cost": MoneyLabel.format_k(def.cost_k),
				"time": ResearchText.duration(ResearchText.planned_ticks(state, def)),
			}
		)
	)
	_show_action(state, def)


## Shows [param text] under the button (a refusal), until the next show_project.
func show_notice(text: String) -> void:
	_reason.text = text


## Returns the panel's lines, top to bottom: heading, name, cost, line, reason.
func lines() -> Array[String]:
	return [_heading.text, _name.text, _cost.text, _line.text, _reason.text]


## Returns the Start or Cancel button.
func get_button() -> Button:
	return _button


## Returns the project shown, or &"".
func get_project() -> StringName:
	return _project


func _show_action(state: GameState, def: ResearchDef) -> void:
	match ResearchText.kind(state, def):
		ResearchText.Kind.DONE:
			_reason.text = tr(&"RESEARCH_STATE_DONE")
			return
		ResearchText.Kind.ACTIVE:
			var refund: String = MoneyLabel.format_k(ResearchRules.refund_k(def))
			_button.text = tr(&"RESEARCH_CANCEL").format({"refund": refund})
			_button.disabled = false
			_button.visible = true
			return
	var check: CommandResult = ResearchRules.can_start(state, def.id)
	_button.text = tr(&"RESEARCH_START")
	_button.disabled = not check.is_ok
	_button.visible = true
	if not check.is_ok:
		_reason.text = ResearchText.refusal(check, state)


func _add_button() -> Button:
	var button := Button.new()
	button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	button.focus_mode = FOCUS_ALL
	button.visible = false
	button.pressed.connect(func() -> void: action_pressed.emit(_project))
	add_child(button)
	return button


func _add_label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label
