## Tests for the capacitor gauge's three states in the Gate Room: no capacitors (the hold
## button "Install capacitor bank (6 h)", and the Dial button disabled with "No capacitors
## installed."), installing (time left and a progress bar) and the normal charge display; in
## English and Brazilian Portuguese, inside the 1280 x 720 window; the install reached and held
## with the mouse path and with the gamepad. It never shows a lock energy.
## Bible: gate-and-address-spec.md#the-dial-console, game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.simulation()
	_simulation.state.power = PowerState.starting(_simulation.state.balance)
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _gauge() -> CapacitorGauge:
	return _view.find_child("CapacitorGauge", true, false) as CapacitorGauge


func _install() -> HoldButton:
	return _gauge().get_install_button()


func _dial_controls() -> DialControls:
	return _view.find_child("DialControls", true, false) as DialControls


func _hold_install() -> void:
	_install().begin_hold()
	_install().advance(HoldButton.HOLD_SECONDS)


## Controls reached from [param start] by repeatedly moving focus up, down, left and right
## (the gamepad's d-pad and stick).
func _reach_by_directions(start: Control) -> Array[Control]:
	var seen: Array[Control] = [start]
	var pending: Array[Control] = [start]
	var sides: Array[Side] = [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]
	while not pending.is_empty():
		var current: Control = pending.pop_back()
		for side: Side in sides:
			var next: Control = current.find_valid_focus_neighbor(side)
			if next != null and _view.is_ancestor_of(next) and not seen.has(next):
				seen.append(next)
				pending.append(next)
	return seen


func _send_gamepad_accept(is_pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = is_pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## The laid-out Gate Room fits the 1280 x 600 view area of the minimum window, and the
## gauge's status and install button are as wide as their text.
func _assert_fits() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var content: Control = _view.get_node("Margin") as Control
	var needed: Vector2 = content.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)
	var install: HoldButton = _install()
	if install.is_visible_in_tree():
		var font: Font = install.get_theme_font(&"font")
		var size: int = install.get_theme_font_size(&"font_size")
		var width: float = font.get_string_size(install.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		assert_float(install.size.x).is_greater_equal(width)


## A new game: no capacitors, the install button, no bar; the Dial button is disabled with
## the reason from the dial controls, even with a full address in the slots.
func test_no_capacitors_state_in_both_languages() -> void:
	assert_int(_gauge().get_mode()).is_equal(CapacitorGauge.Mode.EMPTY)
	assert_str(_gauge().get_values_text()).is_equal("No capacitors installed.")
	assert_bool(_install().is_visible_in_tree()).is_true()
	assert_str(_install().text).is_equal("Install capacitor bank (6 h)")
	assert_bool((_gauge().get_node("BarArea") as Control).visible).is_false()
	Fixture.select(_view, Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	assert_bool(_dial_controls().get_dial_button().disabled).is_true()
	assert_str(_dial_controls().get_reason_text()).is_equal("No capacitors installed.")
	await _assert_fits()
	TranslationServer.set_locale("pt_BR")
	await get_tree().process_frame
	assert_str(_gauge().get_values_text()).is_equal("Nenhum capacitor instalado.")
	assert_str(_install().text).is_equal("Instalar banco de capacitores (6 h)")
	await _assert_fits()


## Holding the install button starts the install: the time left and a progress bar, which
## follow the clock; after 360 ticks the normal charge display, with no lock energy.
func test_install_progress_then_charge_display() -> void:
	_hold_install()
	assert_int(_simulation.state.power.install_ticks_left).is_equal(360)
	assert_int(_gauge().get_mode()).is_equal(CapacitorGauge.Mode.INSTALLING)
	assert_bool(_install().is_visible_in_tree()).is_false()
	assert_str(_gauge().get_values_text()).is_equal("Installing: 6 h left")
	SimClock.step_ticks(160)
	assert_str(_gauge().get_values_text()).is_equal("Installing: 3 h 20 min left")
	assert_float(_gauge().get_bar_value()).is_equal(160.0)
	assert_float(_gauge().get_bar_max()).is_equal(360.0)
	await _assert_fits()
	TranslationServer.set_locale("pt_BR")
	await get_tree().process_frame
	assert_str(_gauge().get_values_text()).is_equal("Instalando: faltam 3 h 20 min")
	await _assert_fits()
	TranslationServer.set_locale("en")
	SimClock.step_ticks(200)
	assert_int(_gauge().get_mode()).is_equal(CapacitorGauge.Mode.CHARGE)
	assert_float(_simulation.state.power.capacity_mwh).is_equal(400.0)
	assert_float(_gauge().get_bar_max()).is_equal(400.0)
	assert_str(_gauge().get_values_text()).contains("400")
	assert_bool(_install().is_visible_in_tree()).is_false()
	await _assert_fits()


## The gauge shows charge only: the text holds no lock energy of the loaded address.
func test_charge_display_never_shows_the_lock_energy() -> void:
	_hold_install()
	SimClock.step_ticks(360)
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	Fixture.select(_view, address)
	var lock: float = GateQueries.lock_energy_mwh(_simulation.state, address)
	assert_str(_gauge().get_values_text()).not_contains(String.num(lock, 1))


## A hold released early installs nothing, and a second hold after the start is not offered.
func test_early_release_installs_nothing() -> void:
	_install().begin_hold()
	_install().advance(HoldButton.HOLD_SECONDS - 0.1)
	_install().cancel_hold()
	assert_int(_simulation.state.power.install_ticks_left).is_equal(0)
	assert_int(_gauge().get_mode()).is_equal(CapacitorGauge.Mode.EMPTY)


## With the gamepad: the install button is reached by directions from the view's default
## control, and holding A on it starts the install; focus then moves back into the view.
func test_gamepad_reaches_and_holds_the_install_button() -> void:
	await get_tree().process_frame
	assert_int(_install().focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(_reach_by_directions(_view.get_default_focus()).has(_install())).is_true()
	_install().grab_focus()
	_send_gamepad_accept(true)
	assert_bool(_install().is_holding()).is_true()
	await get_tree().create_timer(HoldButton.HOLD_SECONDS + 0.3).timeout
	_send_gamepad_accept(false)
	assert_int(_simulation.state.power.install_ticks_left).is_equal(360)
	await get_tree().process_frame
	await get_tree().process_frame
	var focused: Control = get_viewport().gui_get_focus_owner()
	assert_object(focused).is_not_null()
	assert_bool(_view.is_ancestor_of(focused)).is_true()
