class_name ScenarioList
extends VBoxContainer
## The main menu's scenario list: one key per shipped scenario in order, with its title and a
## line of description under it, and Back.
## Bible: docs/scenarios.md (M4.6-03)

## The player chose [param scenario].
signal scenario_chosen(scenario: ScenarioDef)
## The player backed out.
signal cancelled

## Goes back.
var back_button := Button.new()

var _rows := VBoxContainer.new()


func _init() -> void:
	name = &"ScenarioList"
	add_child(_rows)
	back_button.text = &"SAVES_BACK"
	back_button.pressed.connect(cancelled.emit)
	add_child(back_button)


## Lists [param scenarios].
func show_scenarios(scenarios: Array[ScenarioDef]) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for scenario: ScenarioDef in scenarios:
		var button := Button.new()
		button.text = scenario.title_key
		button.theme_type_variation = &"KeyButton"
		button.pressed.connect(scenario_chosen.emit.bind(scenario))
		_rows.add_child(button)
		var line := Label.new()
		line.text = scenario.description_key
		line.theme_type_variation = &"StencilLabel"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(line)


## The scenario keys, in order.
func rows() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _rows.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


## The first key, or Back with none.
func first_focus() -> Control:
	var found: Array[Button] = rows()
	return back_button if found.is_empty() else found[0]
