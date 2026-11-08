class_name RescueAlert
extends PanelContainer
## The rescue alert (docs/content/m3-beyond-the-ring.md section 7): a strip over the top of the
## current tab, never a modal (only the strip itself takes clicks; the tab below stays usable).
## It opens, taking focus, when a team misses its check-in, and shows the title and window
## left, how to rescue, the threat as the report knows it with the plain warning that the
## outcome is not certain and that waiting lowers the odds (no percentages, owner), the charge
## forecast and its verdict. Charge at maximum (shown while the rate is too slow) posts a
## ChargeAtMaximumCommand; Go to Gate Room asks the shell for that tab; Close (or B) hides it,
## and the top bar's alert stack opens it again while the window is open. It redraws on every
## tick and power or rescue event, when shown and after each press, so it updates while paused.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7

## The player asked to go to the Gate Room.
signal gate_room_requested
## The alert opened or closed.
signal changed

var _simulation: Simulation = null
var _title := Label.new()
var _window := Label.new()
var _how := Label.new()
var _odds := Label.new()
var _charge := Label.new()
var _verdict := Label.new()
var _max_button := Button.new()
var _gate_button := Button.new()
var _close_button := Button.new()


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	var header := HBoxContainer.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override(&"font_size", 18)
	header.add_child(_title)
	header.add_child(_window)
	column.add_child(header)
	for label: Label in [_how, _odds, _charge, _verdict]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	for label: Label in [_title, _window, _how, _odds, _charge, _verdict]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_build_buttons())
	_max_button.pressed.connect(charge_at_maximum)
	_gate_button.pressed.connect(_on_gate_pressed)
	_close_button.pressed.connect(close)


func _enter_tree() -> void:
	for event: Signal in _events():
		event.connect(_on_event)
	EventBus.check_in_missed.connect(_on_check_in_missed)


func _exit_tree() -> void:
	for event: Signal in _events():
		event.disconnect(_on_event)
	EventBus.check_in_missed.disconnect(_on_check_in_missed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Connects the alert to [param simulation]; open when its rescue window is (a loaded game).
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	visible = false
	if is_window_open():
		open()
	else:
		changed.emit()


## True while [param simulation]'s rescue window is open.
func is_window_open() -> bool:
	return _simulation != null and _simulation.state.expedition.mode == ExpeditionState.Mode.MISSING


## The alert stack's entry for the open window; "" while none is open.
func stack_entry() -> String:
	return RescueAlertText.stack_entry(_simulation.state) if is_window_open() else ""


## Shows the alert and focuses its first button. Only while the rescue window is open.
func open() -> void:
	if not is_window_open():
		return
	visible = true
	refresh()
	var focus: Control = get_default_focus()
	if is_visible_in_tree():
		focus.grab_focus()
	changed.emit()


## Hides the alert; it stays on the alert stack while the window is open.
func close() -> void:
	if not visible:
		return
	visible = false
	changed.emit()


## Submits Charge at maximum and redraws.
func charge_at_maximum() -> void:
	if _simulation == null or not _max_button.visible:
		return
	_simulation.submit(ChargeAtMaximumCommand.new())
	refresh()
	if is_visible_in_tree() and not _buttons().has(get_viewport().gui_get_focus_owner()):
		get_default_focus().grab_focus()


## Redraws the alert from the state; closes it once the window is no longer open.
func refresh() -> void:
	if not visible:
		return
	if not is_window_open():
		close()
		return
	var state: GameState = _simulation.state
	_title.text = RescueAlertText.title(state)
	_window.text = RescueAlertText.window(state)
	_how.text = RescueAlertText.how(state)
	_odds.text = RescueAlertText.odds(state)
	_charge.text = RescueAlertText.charge(state)
	_verdict.text = RescueAlertText.verdict(state)
	_max_button.visible = RescueForecast.status(state) != RescueForecast.ON_TIME
	_max_button.disabled = RescueForecast.max_charge_mw(state) <= PowerRules.charge_mw(state)
	_max_button.focus_mode = Control.FOCUS_NONE if _max_button.disabled else Control.FOCUS_ALL
	_link_focus()


## Returns the first button that can take focus.
func get_default_focus() -> Control:
	return _buttons()[0]


## Returns the alert's lines in order: title, window, how, odds, charge, verdict.
func texts() -> Array[String]:
	var lines: Array[String] = []
	for label: Label in [_title, _window, _how, _odds, _charge, _verdict]:
		lines.append(label.text)
	return lines


## Returns the Charge at maximum button.
func get_max_button() -> Button:
	return _max_button


## Returns the Go to Gate Room button.
func get_gate_button() -> Button:
	return _gate_button


## Returns the Close button.
func get_close_button() -> Button:
	return _close_button


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_max_button.text = &"RESCUE_ALERT_CHARGE_MAX"
	_gate_button.text = &"RESCUE_ALERT_GO_GATE"
	_close_button.text = &"RESCUE_ALERT_CLOSE"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for control: Control in [_max_button, _gate_button, spacer, _close_button]:
		row.add_child(control)
	return row


func _buttons() -> Array[Control]:
	var found: Array[Control] = []
	for button: Button in [_max_button, _gate_button, _close_button]:
		if button.visible and not button.disabled:
			found.append(button)
	return found


func _link_focus() -> void:
	OverlayFocus.trap_all(_buttons())


func _events() -> Array[Signal]:
	return [
		EventBus.tick_advanced,
		EventBus.power_allocation_changed,
		EventBus.rescue_signal_sent,
		EventBus.rescue_signal_failed,
		EventBus.team_rescued,
		EventBus.team_lost,
		EventBus.wormhole_closed,
	]


func _on_event(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


func _on_check_in_missed(_world_id: StringName) -> void:
	open.call_deferred()


func _on_gate_pressed() -> void:
	close()
	gate_room_requested.emit()
