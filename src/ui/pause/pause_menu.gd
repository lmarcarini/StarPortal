class_name PauseMenu
extends Control
## The pause menu over the game: Resume, Save, Load, Main menu, Quit to desktop. Opening it
## holds the clock (a hold never undoes the player's own pause, so a paused game stays paused)
## and Resume releases it at the speed it had. Save and Load use the slot list; Load asks to
## confirm when the game has time since its last save; Main menu and Quit ask to confirm.
## The shell opens it on pause_menu (Esc, gamepad Start) when nothing else took that key.
## Bible: docs/bible/technical-architecture.md#save-and-load (M4.6-02)

## Load [param slot] (the shell restarts the game from it).
signal load_requested(slot: StringName)
## Save into [param slot].
signal save_requested(slot: StringName)
## Back to the main menu.
signal menu_requested

## The SimClock hold reason while the menu is open.
const HOLD: StringName = &"pause_menu"

## The menu's keys.
var resume_button := Button.new()
var save_button := Button.new()
var load_button := Button.new()
var menu_button := Button.new()
var quit_button := Button.new()
## The Failure states setting (M4c-15), until a settings screen exists.
var failure_toggle := CheckButton.new()
## Opens the team report by itself when a team comes home (gameplay/auto_open_team_report).
var report_toggle := CheckButton.new()
## The confirm question and its Yes key.
var question := Label.new()
var yes_button := Button.new()
## The save list.
var slots := SlotList.new()
## The tick of the last save or load; the game has unsaved time when the clock is past it.
var saved_tick: int = -1

var _keys := VBoxContainer.new()
var _confirm := HBoxContainer.new()
var _pending: Callable = Callable()


func _init() -> void:
	name = &"PauseMenu"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiPalette.GROUND, 0.75)
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
	_build_keys(column)
	slots.visible = false
	slots.cancelled.connect(_show_keys)
	slots.slot_chosen.connect(_on_slot_chosen)
	column.add_child(slots)


func _build_keys(column: VBoxContainer) -> void:
	var labels: Dictionary[Button, StringName] = {
		resume_button: &"PAUSE_RESUME",
		save_button: &"PAUSE_SAVE",
		load_button: &"PAUSE_LOAD",
		menu_button: &"MENU_RETURN",
		quit_button: &"PAUSE_QUIT",
	}
	for button: Button in labels:
		button.text = labels[button]
		button.theme_type_variation = &"KeyButton"
		button.custom_minimum_size = Vector2(320, 40)
		_keys.add_child(button)
	failure_toggle.text = &"PAUSE_FAILURE_STATES"
	failure_toggle.set_pressed_no_signal(Settings.get_bool(&"gameplay", &"failure_states"))
	failure_toggle.toggled.connect(_on_failure_toggled)
	_keys.add_child(failure_toggle)
	report_toggle.text = &"PAUSE_AUTO_TEAM_REPORT"
	report_toggle.set_pressed_no_signal(Settings.get_bool(&"gameplay", &"auto_open_team_report"))
	report_toggle.toggled.connect(
		func(on: bool) -> void: Settings.set_value(&"gameplay", &"auto_open_team_report", on)
	)
	_keys.add_child(report_toggle)
	column.add_child(_keys)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(question)
	yes_button.text = &"PAUSE_YES"
	yes_button.pressed.connect(_on_yes)
	_confirm.add_child(yes_button)
	var no := Button.new()
	no.text = &"PAUSE_NO"
	no.pressed.connect(_show_keys)
	_confirm.add_child(no)
	column.add_child(_confirm)
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_show_slots.bind(SlotList.Mode.SAVE))
	load_button.pressed.connect(_ask_load)
	menu_button.pressed.connect(_ask.bind(&"PAUSE_CONFIRM_MENU", menu_requested.emit))
	quit_button.pressed.connect(_ask.bind(&"PAUSE_CONFIRM_QUIT", _quit))


## Opens the menu and holds the clock.
func open() -> void:
	if visible:
		return
	visible = true
	SimClock.hold(HOLD)
	_show_keys()


## Closes the menu and releases the clock (it runs again only if it was running).
func close() -> void:
	if not visible:
		return
	visible = false
	SimClock.release(HOLD)


## True while open.
func is_open() -> bool:
	return visible


## Esc or (B) inside the menu: backs out of a list or a question, else resumes.
func back() -> void:
	if slots.visible or _confirm.visible:
		_show_keys()
	else:
		close()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_menu"):
		back()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if (
		visible
		and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_menu"))
	):
		back()
		get_viewport().set_input_as_handled()


func _show_keys() -> void:
	_keys.visible = true
	slots.visible = false
	_confirm.visible = false
	question.visible = false
	resume_button.grab_focus.call_deferred()


func _show_slots(mode: SlotList.Mode) -> void:
	_keys.visible = false
	_confirm.visible = false
	question.visible = false
	slots.visible = true
	slots.show_mode(mode)
	slots.first_focus().grab_focus.call_deferred()


func _ask(key: StringName, then: Callable) -> void:
	_pending = then
	_keys.visible = false
	slots.visible = false
	question.text = tr(key)
	question.visible = true
	_confirm.visible = true
	yes_button.grab_focus.call_deferred()


func _ask_load() -> void:
	_show_slots(SlotList.Mode.LOAD)


func _on_slot_chosen(slot: StringName) -> void:
	if slots.mode() == SlotList.Mode.LOAD:
		var simulation: Simulation = SimClock.simulation
		if simulation != null and simulation.state.clock.tick != saved_tick:
			_ask(&"PAUSE_CONFIRM_LOAD", _load.bind(slot))
			return
		_load(slot)
		return
	save_requested.emit(slot)
	_show_keys()


func _load(slot: StringName) -> void:
	close()
	load_requested.emit(slot)


func _on_yes() -> void:
	var then: Callable = _pending
	_pending = Callable()
	if then.is_valid():
		then.call()


func _on_failure_toggled(on: bool) -> void:
	Settings.set_value(&"gameplay", &"failure_states", on)
	if SimClock.simulation != null:
		ShellBoot.apply_settings(SimClock.simulation)


func _quit() -> void:
	get_tree().quit()
