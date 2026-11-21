## The Shutter (M4c-10): installed after research; closed it refuses dialling and answering;
## it stops a wave at the end of the warning for 100 MWh (Confidence +3), fails with too
## little stored, is ignored by breaches_shutter; the gate chip says SHUTTER; saves keep it.
## Bible: docs/content/m4c-incursions.md section 6
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = GameState.new_game(6, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 8
	_state.unit_defs[unit.id] = unit
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [unit.id]
	def.group_counts = [2]
	def.warning_ticks = 3
	_state.incursion_defs[def.id] = def


func _install() -> void:
	_state.research.done.append(&"iris_studies")
	for room: RoomState in _state.base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			(
				assert_bool(
					InstallCommand.create(room.id, ShutterRules.DEF_ID).validate(_state).is_ok
				)
				. is_true()
			)
			InstallCommand.create(room.id, ShutterRules.DEF_ID).apply(_state)
			room.installations[0].build_ticks_left = 0


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func test_needs_installing_and_refuses_traffic_when_closed() -> void:
	assert_str(String(SetShutterCommand.create(true).validate(_state).error_code)).is_equal(
		"not_installed"
	)
	_install()
	SetShutterCommand.create(true).apply(_state)
	var galaxy: GalaxyCatalogue = _state.galaxy
	var address: GateAddress = galaxy.address_of(galaxy.home().id, galaxy.home().origin_glyph)
	assert_str(String(DialCommand.create(address).validate(_state).error_code)).is_equal(
		"shutter_closed"
	)
	_state.gate.incoming_faction = &"faction_kindred"
	assert_str(String(AnswerIncomingCommand.new().validate(_state).error_code)).is_equal(
		"shutter_closed"
	)
	_state.gate.incoming_faction = &""
	assert_str(String(TopBarText.gate_status(_state))).is_equal("shutter")
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_int(GameState.from_dict(data).gate.shutter).is_equal(GateState.Shutter.CLOSED)


func test_a_closed_shutter_stops_the_wave() -> void:
	_install()
	_state.power.stored_mwh = 150.0
	IncursionRules.start(_state, &"incursion_test")
	SetShutterCommand.create(true).apply(_state)
	var before: int = _state.committee.confidence
	var system := IncursionSystem.new()
	for index: int in 3:
		system.tick(_state)
	assert_bool(_state.incursion.is_active()).is_false()
	assert_float(_state.power.stored_mwh).is_less_equal(50.0)
	assert_int(_state.committee.confidence).is_equal(before + 30)


func test_too_little_energy_or_breaches_shutter_gets_through() -> void:
	_install()
	_state.power.stored_mwh = 10.0
	IncursionRules.start(_state, &"incursion_test")
	SetShutterCommand.create(true).apply(_state)
	var system := IncursionSystem.new()
	for index: int in 3:
		system.tick(_state)
	assert_int(_state.incursion.phase).is_equal(IncursionState.Phase.BREACH)
	assert_str(String(SetShutterCommand.create(true).validate(_state).error_code)).is_empty()
