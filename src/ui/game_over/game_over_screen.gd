class_name GameOverScreen
extends Control
## The game over screen (M4c-15): over the whole game, with the top bar still readable
## through it and nothing clickable behind. It names the cause with a line of explanation,
## the date and three figures, and offers Load last save, Load… and Main menu. It shows on
## game_failed, and at once for a loaded game that had already failed (it checks each frame
## while hidden, which costs one comparison).
## Bible: docs/content/m4c-incursions.md section 8

## Load [param slot].
signal load_requested(slot: StringName)
## Back to the main menu.
signal menu_requested

var title := Label.new()
var explanation := Label.new()
var date := Label.new()
var figures := Label.new()
var last_button := Button.new()
var load_button := Button.new()
var menu_button := Button.new()
var slots := SlotList.new()

var _keys := VBoxContainer.new()


func _init() -> void:
	name = &"GameOverScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiPalette.GROUND, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelBezel"
	centre.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_build(column)


func _build(column: VBoxContainer) -> void:
	title.add_theme_font_size_override(&"font_size", 32)
	title.add_theme_color_override(&"font_color", UiPalette.ALARM)
	for label: Label in [title, explanation, date, figures]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 520
		column.add_child(label)
	var labels: Dictionary[Button, StringName] = {
		last_button: &"GAME_OVER_LOAD_LAST",
		load_button: &"PAUSE_LOAD",
		menu_button: &"MENU_RETURN",
	}
	for button: Button in labels:
		button.text = labels[button]
		button.theme_type_variation = &"KeyButton"
		button.custom_minimum_size = Vector2(320, 40)
		_keys.add_child(button)
	column.add_child(_keys)
	slots.visible = false
	slots.cancelled.connect(_show_keys)
	slots.slot_chosen.connect(load_requested.emit)
	column.add_child(slots)
	last_button.pressed.connect(_load_last)
	load_button.pressed.connect(_show_slots)
	menu_button.pressed.connect(menu_requested.emit)


func _enter_tree() -> void:
	EventBus.game_failed.connect(_on_game_failed)


func _exit_tree() -> void:
	EventBus.game_failed.disconnect(_on_game_failed)


func _process(_delta: float) -> void:
	var simulation: Simulation = SimClock.simulation
	var failed: bool = simulation != null and simulation.state.outcome.has_failed()
	if failed != visible:
		if failed:
			show_for(simulation.state)
		else:
			visible = false


## Shows the end of [param state].
func show_for(state: GameState) -> void:
	var cause: StringName = state.outcome.cause
	title.text = GameOverText.title(cause)
	explanation.text = GameOverText.explanation(cause)
	date.text = GameOverText.date(state)
	figures.text = GameOverText.figures(state)
	last_button.disabled = newest_slot().is_empty()
	visible = true
	_show_keys()


## The newest save slot (autosaves included), or &"" when there is none.
static func newest_slot() -> StringName:
	var all: Array[Dictionary] = SaveService.list_slots()
	return all[0]["slot"] if not all.is_empty() else &""


func _load_last() -> void:
	var slot: StringName = newest_slot()
	if not slot.is_empty():
		load_requested.emit(slot)


func _show_keys() -> void:
	slots.visible = false
	_keys.visible = true
	var first: Button = last_button if not last_button.disabled else load_button
	first.grab_focus.call_deferred()


func _show_slots() -> void:
	_keys.visible = false
	slots.visible = true
	slots.show_mode(SlotList.Mode.LOAD)
	slots.first_focus().grab_focus.call_deferred()


func _on_game_failed(_cause: StringName) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation != null:
		show_for(simulation.state)
