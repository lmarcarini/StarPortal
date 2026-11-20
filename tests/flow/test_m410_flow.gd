## The M4.10 frame end to end on the real content, from the "Gate station" scenario in the
## full shell: from the Base, a candidate on the wire and HIRE; a lab idle card starts a
## project; the phone call card ANSWERs and the briefing's request is accepted inside the
## conversation; the gate monitor lights during a dial from another station; the station keys
## reach every old screen.
## Bible: docs/content/interface-rethink.md sections 3, 5 and 6
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	TranslationServer.set_locale("en")
	var loaded: Result = SaveService.load_file(SCENARIO, GameDefs.from_registry(Registry))
	assert_bool(loaded.is_ok).override_failure_message(str(loaded.detail)).is_true()
	var state: GameState = loaded.value
	GameStart.start_scenario(&"gate_station", state)
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_runner = scene_runner(_shell)
	await _runner.simulate_frames(3)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	GameStart.reset()


func _sim() -> Simulation:
	return SimClock.simulation


func _wire() -> Wire:
	return _shell.frame.wire


## Presses key [param key_id] on the wire card of [param kind].
func _press(kind: StringName, key_id: StringName) -> void:
	_wire().refresh()
	var card: WireCard = _wire().card_of(kind)
	assert_object(card).override_failure_message("no %s card" % kind).is_not_null()
	for key: RefKey in card.get_keys():
		if key.name == String(key_id):
			assert_bool(key.disabled).is_false()
			key.pressed.emit()
			await _runner.simulate_frames(1)
			return
	assert_bool(false).override_failure_message("no %s key on %s" % [key_id, kind]).is_true()


func test_the_frame_end_to_end() -> void:
	await _hire_from_the_base()
	await _start_research_from_the_wire()
	await _answer_and_accept_in_the_conversation()
	await _monitor_lights_during_a_dial()
	await _station_keys_reach_every_screen()


## From the Base: the candidate card's HIRE hires the first candidate.
func _hire_from_the_base() -> void:
	_shell.frame.station_keys.get_key(&"base").pressed.emit()
	await _runner.simulate_frames(1)
	assert_str(String(_shell.view_switcher.current_station())).is_equal("base")
	var people: int = _sim().state.staff.people.size()
	var candidate: StringName = _sim().state.recruitment.candidates[0].id
	await _press(&"candidate_waiting", &"hire")
	assert_int(_sim().state.staff.people.size()).is_equal(people + 1)
	assert_object(_sim().state.recruitment.find_candidate(candidate)).is_null()


## A finished, powered lab with nothing to do: the lab idle card's one key opens the Lab.
func _start_research_from_the_wire() -> void:
	var state: GameState = _sim().state
	var lab: RoomState = PowerFixture.lab(state)
	lab.build_ticks_left = 0
	lab.powered_on = true
	StaffChanges.auto_assign(state, lab)
	EventBus.room_built.emit(lab.id)
	_shell.frame.alert_list.refresh()
	await _runner.simulate_frames(1)
	var card: WireCard = _wire().card_of(&"lab_idle")
	assert_object(card).is_not_null()
	assert_int(card.get_keys().size()).is_equal(1)
	var first: RefKey = card.get_keys()[0]
	assert_bool(first.disabled).is_false()
	first.pressed.emit()
	await _runner.simulate_frames(1)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("research")
	var project: StringName = WireActions.research(state)[0].id
	assert_bool(_sim().submit(StartResearchCommand.create(project)).is_ok).is_true()
	_shell.frame.alert_list.refresh()
	await _runner.simulate_frames(1)


## The phone card's ANSWER starts the briefing; ACCEPT at its offer step takes the request.
func _answer_and_accept_in_the_conversation() -> void:
	await _press(&"phone_call", &"answer")
	var state: GameState = _sim().state
	assert_object(state.conversations.active).is_not_null()
	for guard: int in 20:
		var node: ConversationNodeDef = ConversationRules.current_node(state)
		if node != null and node.is_offer():
			break
		_sim().submit(AdvanceConversationCommand.new())
	assert_bool(ConversationRules.current_node(state).is_offer()).is_true()
	assert_bool(_shell.get_dialogue_screen().terms.visible).is_true()
	_sim().submit(ChooseOptionCommand.new(OfferStep.Answer.ACCEPT))
	var record: RequestRecord = RequestRules.open_instance(state, &"request_survey_hearth")
	assert_int(record.state).is_equal(RequestRecord.RequestState.ACTIVE)
	while state.conversations.active != null:
		_sim().submit(AdvanceConversationCommand.new())
	await _runner.simulate_frames(1)


## From the Office, a dial: the gate monitor shows the Ring dialling.
func _monitor_lights_during_a_dial() -> void:
	_shell.frame.station_keys.get_key(&"office").pressed.emit()
	await _runner.simulate_frames(2)
	var monitor: GateMonitor = _shell.frame.gate_monitor
	assert_bool(monitor.visible).is_true()
	assert_bool(monitor.is_live()).is_false()
	var state: GameState = _sim().state
	var world: StringName = state.address_book.entries[0].world_id
	var address: GateAddress = state.galaxy.address_of(world, state.galaxy.home().origin_glyph)
	state.power.stored_mwh = PowerRules.capacity_mwh(state)
	assert_bool(_sim().submit(DialCommand.create(address)).is_ok).is_true()
	await _runner.simulate_frames(2)
	assert_bool(monitor.is_live()).is_true()
	assert_int(monitor.current_look().phase).is_equal(RingLook.Phase.DIALING)


## Every old screen through a station key and its folders.
func _station_keys_reach_every_screen() -> void:
	var switcher: ViewSwitcher = _shell.view_switcher
	for view_id: StringName in switcher.get_view_ids():
		var station: StringName = switcher.station_of(view_id)
		_shell.frame.station_keys.get_key(station).pressed.emit()
		switcher.show_view(view_id)
		await _runner.simulate_frames(1)
		assert_str(String(switcher.current_view_id())).is_equal(String(view_id))
		assert_str(String(switcher.current_station())).is_equal(String(station))
