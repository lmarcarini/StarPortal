## Tests for the capacitor gauge's two states in the Gate Room: no Capacitor Bank built ("No
## capacitors installed." and the Dial button disabled with that reason) and the charge display
## once a bank stands; in English and Brazilian Portuguese, inside the 1280 x 720 window. It
## never shows a lock energy. The bank itself is built as a room (docs/content/m2-base.md
## section 3).
## Bible: gate-and-address-spec.md#the-dial-console, docs/content/m2-base.md section 3,
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
	PowerFixture.remove_banks(_simulation.state)
	_simulation.state.power.stored_mwh = 0.0
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


func _dial_controls() -> DialControls:
	return _view.find_child("DialControls", true, false) as DialControls


## The laid-out Gate Room fits the 1280 x 600 view area of the minimum window.
func _assert_fits() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var content: Control = _view.get_node("Margin") as Control
	var needed: Vector2 = content.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)


## No bank: "No capacitors installed.", no bar; the Dial button is disabled with the reason
## from the dial controls, even with a full address in the slots.
func test_no_capacitors_state_in_both_languages() -> void:
	assert_int(_gauge().get_mode()).is_equal(CapacitorGauge.Mode.EMPTY)
	assert_str(_gauge().get_values_text()).is_equal("No capacitors installed.")
	assert_bool((_gauge().get_node("BarArea") as Control).visible).is_false()
	Fixture.select(_view, Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	assert_bool(_dial_controls().get_dial_button().disabled).is_true()
	assert_str(_dial_controls().get_reason_text()).is_equal("No capacitors installed.")
	await _assert_fits()
	TranslationServer.set_locale("pt_BR")
	await get_tree().process_frame
	assert_str(_gauge().get_values_text()).is_equal("Nenhum capacitor instalado.")
	await _assert_fits()


## Once a bank stands the gauge shows its charge against the capacity, following the clock.
func test_charge_display_after_a_bank_is_built() -> void:
	PowerFixture.add_bank(_simulation.state, 26)
	SimClock.step_ticks(60)
	assert_int(_gauge().get_mode()).is_equal(CapacitorGauge.Mode.CHARGE)
	assert_float(_gauge().get_bar_max()).is_equal(100_000.0)
	assert_float(_gauge().get_bar_value()).is_equal_approx(26.0, 1e-9)
	assert_bool((_gauge().get_node("BarArea") as Control).visible).is_true()
	await _assert_fits()


## The gauge shows charge only: the text holds no lock energy of the loaded address.
func test_charge_display_never_shows_the_lock_energy() -> void:
	PowerFixture.add_bank(_simulation.state, 26)
	SimClock.step_ticks(360)
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	Fixture.select(_view, address)
	var lock: float = GateQueries.lock_energy_mwh(_simulation.state, address)
	assert_str(_gauge().get_values_text()).not_contains(String.num(lock, 1))


func test_build_button_follows_build_and_cancel_while_paused() -> void:
	var state: GameState = _simulation.state
	state.clock.is_paused = true
	var button: Button = _gauge().get_build_button()
	assert_bool(button.visible).is_true()
	var place: PlaceRoomCommand = PowerFixture.build_first_bank(state)
	assert_bool(_simulation.submit(place).is_ok).is_true()
	assert_bool(button.visible).is_false()
	var site: RoomState = state.base.rooms[-1]
	assert_bool(_simulation.submit(CancelBuildCommand.create(site.id)).is_ok).is_true()
	assert_bool(button.visible).is_true()


## An empty bank says so, in both languages, and the gauge still fits.
func test_empty_capacitors_say_so_in_both_languages() -> void:
	PowerFixture.add_bank(_simulation.state, 0)
	SimClock.step_ticks(1)
	assert_str(_gauge().get_values_text()).ends_with(" · Capacitors empty.")
	TranslationServer.set_locale("pt_BR")
	SimClock.step_ticks(1)
	assert_str(_gauge().get_values_text()).ends_with(" · Capacitores vazios.")
	await _assert_fits()
