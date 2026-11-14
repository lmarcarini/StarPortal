## Incursion trigger, warning and breach (M4c-06): the daily chance by standing, the 10-day
## cooldown, the warning countdown with the incursion slow, no dialling and outgoing
## wormholes closed, the breach into the Gate Room, determinism and save mid-countdown.
## Bible: docs/content/m4c-incursions.md section 1
extends GdUnitTestSuite

const OSSAR: StringName = &"faction_ossar"

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = GameState.new_game(7, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 8
	_state.unit_defs[unit.id] = unit
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = OSSAR
	def.group_units = [unit.id]
	def.group_counts = [3]
	_state.incursion_defs[def.id] = def


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func test_daily_chance() -> void:
	assert_float(IncursionRules.daily_chance(-49)).is_equal(0.0)
	assert_float(IncursionRules.daily_chance(-50)).is_equal_approx(0.02, 0.0001)
	assert_float(IncursionRules.daily_chance(-75)).is_equal_approx(0.06, 0.0001)
	assert_float(IncursionRules.daily_chance(-100)).is_equal_approx(0.10, 0.0001)
	assert_float(IncursionRules.daily_chance(-200)).is_equal_approx(0.10, 0.0001)


func test_warning_counts_down_slows_and_breaches() -> void:
	_state.clock.speed_index = 3
	assert_bool(IncursionRules.start(_state, &"incursion_test").is_ok).is_true()
	assert_str(String(IncursionRules.start(_state, &"incursion_test").error_code)).is_equal(
		"incursion_running"
	)
	_ticks(1)
	assert_int(_state.incursion.phase).is_equal(IncursionState.Phase.WARNING)
	assert_int(TimeControl.effective_speed_index(_state.clock)).is_equal(1)
	assert_bool(TimeControl.can_override(_state.clock)).is_false()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(saved)).is_empty()
	assert_int(GameState.from_dict(saved).incursion.countdown).is_equal(29)
	_ticks(28)
	assert_int(_state.incursion.phase).is_equal(IncursionState.Phase.WARNING)
	_ticks(1)
	assert_int(_state.incursion.phase).is_equal(IncursionState.Phase.BREACH)
	assert_int(_state.incursion.groups.size()).is_equal(1)
	var unit: UnitState = _state.incursion.groups[0].units[0]
	assert_str(str(unit.pos)).is_equal(str(IncursionRules.gate_cell(_state)))
	assert_int(_state.incursion.groups[0].units.size()).is_equal(3)


func test_no_dialling_and_outgoing_wormholes_close() -> void:
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.gate.lock_started_tick = _state.clock.tick
	IncursionRules.start(_state, &"incursion_test")
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	var galaxy: GalaxyCatalogue = _state.galaxy
	var address: GateAddress = galaxy.address_of(galaxy.home().id, galaxy.home().origin_glyph)
	assert_str(String(DialCommand.create(address).validate(_state).error_code)).is_equal(
		"incursion"
	)


func test_daily_roll_respects_cooldown_and_is_deterministic() -> void:
	_state.factions.standing[OSSAR] = -100
	var first: Array[int] = _roll_days(_state, 120)
	assert_array(first).is_not_empty()
	var again := GameState.new_game(7, Registry.balance())
	GameSetup.build_new(again, GameDefs.from_registry(Registry))
	again.unit_defs = _state.unit_defs
	again.incursion_defs = _state.incursion_defs
	again.factions.standing[OSSAR] = -100
	assert_array(_roll_days(again, 120)).is_equal(first)
	for index: int in range(1, first.size()):
		assert_int(first[index] - first[index - 1]).is_greater_equal(IncursionRules.COOLDOWN_DAYS)


func _roll_days(state: GameState, days: int) -> Array[int]:
	var system := IncursionSystem.new()
	var started: Array[int] = []
	for day: int in days:
		state.clock.tick = day * TimeMath.TICKS_PER_DAY
		system.on_day(state)
		if state.incursion.is_active():
			started.append(day)
			state.incursion = _reset(state.incursion)
	return started


func _reset(old: IncursionState) -> IncursionState:
	var fresh := IncursionState.new()
	fresh.last_day = old.last_day
	return fresh
