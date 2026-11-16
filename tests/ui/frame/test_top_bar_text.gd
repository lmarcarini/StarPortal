## The top bar's pure text: net change, power, stored energy, gate states and time left.
## Bible: docs/content/interface-pass.md section 3
extends GdUnitTestSuite

var _state: GameState = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var built: Result = GameSetup.build_new(
		GameState.new_game(11, Registry.balance()), GameDefs.from_registry(Registry)
	)
	var simulation: Simulation = built.value
	_state = simulation.state


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)


func test_net_per_day_is_the_ledger_net_line_per_day() -> void:
	var net: CommandLine = CommandLedger.lines(_state).back()
	assert_int(TopBarText.net_per_day(_state)).is_equal(roundi(net.per_day_tenths / 10.0))


func test_net_text_has_a_sign() -> void:
	assert_str(TopBarText.net_text(38)).is_equal("+38/d")
	assert_str(TopBarText.net_text(-12)).is_equal("-12/d")
	assert_str(TopBarText.net_text(0)).is_equal("±0/d")


func test_power_text_is_switched_on_over_supply() -> void:
	var expected: String = (
		"PWR %d/%d MW"
		% [roundi(PowerRules.allocated_mw(_state)), roundi(PowerRules.supply_mw(_state))]
	)
	assert_str(TopBarText.power_text(_state)).is_equal(expected)


func test_stored_text_is_empty_without_capacitors() -> void:
	if PowerRules.capacity_mwh(_state) > 0.0:
		assert_str(TopBarText.stored_text(_state)).starts_with("CAP ")
	else:
		assert_str(TopBarText.stored_text(_state)).is_empty()


func test_gate_follows_all_four_states() -> void:
	assert_str(String(TopBarText.gate_status(_state))).is_equal("idle")
	assert_str(TopBarText.gate_text(_state)).is_equal("GATE: IDLE")
	_state.gate.incoming_faction = &"kindred"
	assert_str(String(TopBarText.gate_status(_state))).is_equal("incoming")
	_state.gate.incoming_faction = &""
	_state.gate.mode = GateState.RingMode.DIALING
	assert_str(String(TopBarText.gate_status(_state))).is_equal("dialling")
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.gate.lock_started_tick = _state.clock.tick
	assert_str(String(TopBarText.gate_status(_state))).is_equal("open")
	assert_str(TopBarText.gate_text(_state)).starts_with("OPEN ")


func test_time_left_in_minutes_and_hours() -> void:
	assert_str(TopBarText.time_left(38)).is_equal("38 min")
	assert_str(TopBarText.time_left(65)).is_equal("1 h 05 min")
	assert_str(TopBarText.time_left(-3)).is_equal("0 min")
