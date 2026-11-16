## The M4.9 Gate station end to end on the real content, from the "Gate station" scenario:
## pick a destination card and press DIAL; with the wormhole open, CAMERA and MOTH on the rail;
## TEAM opens the mission sheet and GO sends the team; CLOSE. A later dial to the team's world:
## HAIL opens the team conversation and Come home is an answer; the team comes home and the
## team report opens; CLOSE. Then a mission order from a closed gate (a card's TEAM key, GO:
## the base dials, the team goes through, the gate closes) and an address composed on the
## alien panel and dialled from its centre key.
## Bible: docs/content/interface-rethink.md sections 4 and 5
extends GdUnitTestSuite

const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")
const M15Player := preload("res://tests/gate/m15_player.gd")
const MAX_TICKS: int = 6 * TimeMath.TICKS_PER_DAY

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null
var _was_on: bool = true


func before_test() -> void:
	TranslationServer.set_locale("en")
	_was_on = Settings.get_bool(&"gameplay", &"auto_open_team_report")
	Settings.set_value(&"gameplay", &"auto_open_team_report", true)
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var loaded: Result = SaveService.load_file(SCENARIO, defs)
	assert_bool(loaded.is_ok).override_failure_message(str(loaded.detail)).is_true()
	var state: GameState = loaded.value
	_simulation = GameSetup.build(state, defs).value
	SimClock.start(_simulation)
	EventBus.bind_simulation(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)


func after_test() -> void:
	Settings.set_value(&"gameplay", &"auto_open_team_report", _was_on)
	EventBus.bind_simulation(null)
	SimClock.stop()
	_holder.free()


func _state() -> GameState:
	return _simulation.state


## Runs ticks until [param done] holds; fails past MAX_TICKS.
func _until(done: Callable) -> void:
	for tick: int in MAX_TICKS:
		if done.call():
			return
		_simulation.advance_tick()
	assert_bool(done.call()).override_failure_message("waited too long").is_true()


func _locked() -> bool:
	return _state().gate.mode == GateState.RingMode.LOCKED


func _idle() -> bool:
	return _state().gate.mode == GateState.RingMode.IDLE


func _talk(answer: int) -> void:
	for guard: int in 20:
		var active: ActiveConversation = _state().conversations.active
		if active == null:
			return
		if active.phase == ActiveConversation.Phase.CHOICE:
			_simulation.submit(ChooseOptionCommand.new(answer))
		else:
			_simulation.submit(AdvanceConversationCommand.new())


func _card_for(world: StringName) -> DestinationCard:
	_view.get_rack().rebuild()
	for card: DestinationCard in _view.get_rack().get_cards():
		if card.get_destination().world_id == world:
			return card
	return null


func test_gate_station_flow() -> void:
	var sill: StringName = M15Player.PUZZLES[0]["world"]
	_dial_and_send(sill)
	_hail_and_bring_home(sill)
	_order_a_mission(sill)
	_compose_and_dial()


## Card, DIAL; CAMERA, MOTH; TEAM, GO; CLOSE.
func _dial_and_send(world: StringName) -> void:
	assert_int(_view.get_rack().get_cards().size()).is_equal(2)
	var card: DestinationCard = _card_for(world)
	card.pressed.emit()
	_view.get_console().press_main_key()
	_until(_locked)
	assert_str(String(_state().gate.connected_world_id)).is_equal(String(world))
	_view.get_rail().refresh()
	_view.get_rail().press(&"camera")
	_until(func() -> bool: return _state().worlds.is_horizon_record_taken(world))
	_view.get_rail().press(&"moth")
	assert_bool(_state().probes.is_moth_out()).is_true()
	_simulation.submit(MothScanCommand.create(MothRules.Scan.RECALL))
	_until(func() -> bool: return not _state().probes.is_moth_out())
	_view.get_rail().press(&"team")
	var sheet: MissionSheet = _view.get_mission_sheet()
	assert_bool(sheet.visible).is_true()
	assert_str(String(sheet.reason())).is_empty()
	sheet.go()
	assert_int(_state().expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	_view.get_console().press_main_key()
	_until(_idle)


## A day later: DIAL the team's world again, HAIL, Come home; the report opens on the return.
func _hail_and_bring_home(world: StringName) -> void:
	_skip(TimeMath.TICKS_PER_DAY)
	_card_for(world).pressed.emit()
	_until(func() -> bool: return GateQueries.ticks_until_ready(_state(), _address(world)) == 0)
	_view.get_console().press_main_key()
	_until(_locked)
	_view.get_rail().refresh()
	_view.get_rail().press(&"hail")
	var active: ActiveConversation = _state().conversations.active
	assert_str(String(active.conversation)).is_equal(String(TeamContactRules.HAIL_CONVERSATION))
	_talk(TeamContactRules.Order.COME_HOME)
	_until(func() -> bool: return _state().expedition.mode == ExpeditionState.Mode.IDLE)
	var report: TeamReportScreen = _view.get_team_report()
	assert_bool(report.visible).is_true()
	report.get_close_key().activated.emit()
	assert_bool(report.visible).is_false()
	_until(_idle)


## The card's TEAM key, GO: the base dials, the team goes, the gate closes.
func _order_a_mission(world: StringName) -> void:
	var card: DestinationCard = _card_for(world)
	card.order_requested.emit(card)
	var sheet: MissionSheet = _view.get_mission_sheet()
	assert_bool(sheet.visible).is_true()
	_until(func() -> bool: return sheet.reason() == &"")
	sheet.go()
	assert_bool(sheet.visible).is_false()
	_until(func() -> bool: return _state().expedition.mode == ExpeditionState.Mode.AWAY)
	_until(_idle)


## + NEW ADDRESS, the glyphs of LINTEL's answer, the centre key: the Ring dials.
func _compose_and_dial() -> void:
	var glyphs: Array = M15Player.PUZZLES[1]["glyphs"]
	var target: GateAddress = _address_of(glyphs)
	_until(func() -> bool: return GateQueries.ticks_until_ready(_state(), target) == 0)
	_view.open_alien_panel()
	var panel: AlienPanel = _view.get_alien_panel()
	for seal: int in AddressBookState.DRAFT_SEALS:
		panel.clear_seal(seal)
	for glyph: int in glyphs:
		panel.press_glyph(glyph)
	panel.dial_requested.emit(panel.get_address())
	assert_int(_state().gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_bool(panel.visible).is_false()


func _skip(ticks: int) -> void:
	for tick: int in ticks:
		_simulation.advance_tick()


func _address(world: StringName) -> GateAddress:
	return _state().galaxy.address_of(world, _state().galaxy.home().origin_glyph)


func _address_of(glyphs: Array) -> GateAddress:
	var coordinates: Array[int] = []
	coordinates.assign(glyphs)
	return GateAddress.create(coordinates, _state().galaxy.home().origin_glyph)
