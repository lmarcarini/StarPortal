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

## Size of a main key, in pixels.
const KEY: Vector2 = Vector2(520, 56)

## The menu's keys (steel keys of the interface reference; Resume amber).
var resume_button := RefKey.new()
var save_button := RefKey.new()
var load_button := RefKey.new()
var menu_button := RefKey.new()
var quit_button := RefKey.new()
## The Failure states setting (M4c-15), until a settings screen exists.
var failure_toggle := LampSwitch.new()
## Opens the team report by itself when a team comes home (gameplay/auto_open_team_report).
var report_toggle := LampSwitch.new()
## The confirm question and its Yes key.
var question := Label.new()
var yes_button := RefKey.new()
## The save list.
var slots := SlotList.new()
## The tick of the last save or load; the game has unsaved time when the clock is past it.
var saved_tick: int = -1

## The GRAPHICS section.
var graphics := GraphicsPanel.new()

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
	var panel := PausePlate.new()
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)
	_build_keys(column)
	slots.visible = false
	slots.cancelled.connect(_show_keys)
	slots.slot_chosen.connect(_on_slot_chosen)
	column.add_child(slots)


func _build_keys(column: VBoxContainer) -> void:
	_keys.add_theme_constant_override(&"separation", 10)
	var labels: Dictionary[RefKey, StringName] = {
		resume_button: &"PAUSE_RESUME",
		save_button: &"PAUSE_SAVE",
		load_button: &"PAUSE_LOAD",
		menu_button: &"MENU_RETURN",
		quit_button: &"PAUSE_QUIT",
	}
	for button: RefKey in labels:
		_style_key(button, labels[button], KEY)
		_keys.add_child(button)
	resume_button.style = RefPaint.KeyStyle.AMBER
	_keys.add_child(PauseMenuParts.heading(&"PAUSE_GAMEPLAY"))
	_switch(failure_toggle, &"PAUSE_FAILURE_STATES", &"failure_states")
	failure_toggle.toggled.connect(_on_failure_toggled)
	_switch(report_toggle, &"PAUSE_AUTO_TEAM_REPORT", &"auto_open_team_report")
	report_toggle.toggled.connect(
		func(on: bool) -> void: Settings.set_value(&"gameplay", &"auto_open_team_report", on)
	)
	_keys.add_child(graphics)
	column.add_child(_keys)
	_build_confirm(column)
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_show_slots.bind(SlotList.Mode.SAVE))
	load_button.pressed.connect(_ask_load)
	menu_button.pressed.connect(_ask.bind(&"PAUSE_CONFIRM_MENU", menu_requested.emit))
	quit_button.pressed.connect(_ask.bind(&"PAUSE_CONFIRM_QUIT", _quit))


func _build_confirm(column: VBoxContainer) -> void:
	PauseMenuParts.style_question(question)
	column.add_child(question)
	_confirm.add_theme_constant_override(&"separation", 10)
	_style_key(yes_button, &"PAUSE_YES", Vector2(255, 56))
	yes_button.style = RefPaint.KeyStyle.HAZARD
	yes_button.pressed.connect(_on_yes)
	_confirm.add_child(yes_button)
	var no := RefKey.new()
	_style_key(no, &"PAUSE_NO", Vector2(255, 56))
	no.pressed.connect(_show_keys)
	_confirm.add_child(no)
	column.add_child(_confirm)


func _style_key(key: RefKey, label: StringName, key_size: Vector2) -> void:
	key.name = String(label).capitalize().replace(" ", "")
	key.label = tr(label).to_upper()
	key.label_size = 20
	key.custom_minimum_size = key_size


func _switch(toggle: LampSwitch, label: StringName, setting: StringName) -> void:
	toggle.label = label
	toggle.custom_minimum_size = Vector2(KEY.x, 48)
	toggle.set_pressed_no_signal(Settings.get_bool(&"gameplay", setting))
	_keys.add_child(toggle)


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
