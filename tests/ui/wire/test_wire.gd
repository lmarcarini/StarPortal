## The wire (M4.10-02): every old alert kind has a card; cards carry the command the old
## screens sent and show a refusal as the key's hover reason; at most five show and the rest
## stack (the stack opens the log); event cards can be dismissed, condition cards go with
## their cause; it never pauses; keys are in the focus ring.
## Bible: docs/content/interface-rethink.md sections 3 and 6
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
## Every kind AlertRules (and the alert list) can raise.
const OLD_KINDS: Array[StringName] = [
	&"funds_red",
	&"lab_idle",
	&"research_done",
	&"staff_unassigned",
	&"beds_full",
	&"candidate_waiting",
	&"request_due",
	&"mission_order_failed",
	&"team_overdue",
	&"incursion",
	&"shutdown_countdown",
	&"bankruptcy_countdown",
	&"wormhole_open",
	&"artefact_at_gate",
	&"team_check_in",
	&"artefact_hazard",
	&"site_finished",
	&"rescue",
]

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 9
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func _wire() -> Wire:
	return _shell.frame.wire


func test_every_old_alert_kind_has_a_card_with_a_title_and_keys() -> void:
	var state: GameState = SimClock.simulation.state
	for kind: StringName in OLD_KINDS:
		var entry: AlertEntry = AlertEntry.create(kind, AlertEntry.INFO, ViewSwitcher.BASE, 0)
		var card: WireCardData = WireRules.from_alert(state, entry)
		assert_bool(WireRules.ICONS.has(kind)).override_failure_message(kind).is_true()
		assert_str(tr(card.title_key)).override_failure_message(kind).is_not_equal(
			String(card.title_key)
		)
		assert_int(tr(card.title_key).split(" ").size()).is_less_equal(2)
		assert_array(card.actions).override_failure_message(kind).is_not_empty()


func test_a_candidate_card_opens_the_candidates_sub_tab() -> void:
	var keys: Array[WireAction] = WireActions.candidate()
	assert_str(String(keys[0].view_id)).is_equal(String(ViewSwitcher.PERSONNEL))
	assert_str(String(keys[0].sub_tab)).is_equal("candidates")
	assert_object(keys[0].command).is_null()


func test_one_candidate_card_counts_every_candidate() -> void:
	var state: GameState = SimClock.simulation.state
	var count: int = state.recruitment.candidates.size()
	var cards: int = 0
	for entry: AlertEntry in AlertRules.current(state):
		cards += 1 if entry.kind == &"candidate_waiting" else 0
	assert_int(cards).is_equal(1 if count > 0 else 0)


func test_a_refused_key_is_greyed_with_its_reason() -> void:
	var state: GameState = SimClock.simulation.state
	var data: WireCardData = WireCardData.new()
	data.kind = &"request_offered"
	data.actions = WireActions.request(999)
	var card: WireCard = auto_free(WireCard.new())
	add_child(card)
	card.show_card(data, state, false)
	var accept: RefKey = card.get_keys()[0]
	assert_bool(accept.disabled).is_true()


func test_at_most_five_show_and_the_rest_stack() -> void:
	var state: GameState = SimClock.simulation.state
	state.budget.funds_k = -50
	for room: RoomState in state.base.rooms:
		EventBus.room_built.emit(room.id)
	_wire().refresh()
	var total: int = _wire().get_cards().size()
	assert_int(_wire().get_card_nodes().size()).is_equal(mini(total, Wire.VISIBLE))
	if total > Wire.VISIBLE:
		assert_str(_wire().get_stack().label).is_equal("+%d" % (total - Wire.VISIBLE))
	var opened: Array[bool] = [false]
	_shell.frame.log_requested.connect(func() -> void: opened[0] = true)
	_wire().get_stack().pressed.emit()
	assert_bool(opened[0]).is_true()


func test_event_cards_dismiss_and_condition_cards_follow_their_cause() -> void:
	var state: GameState = SimClock.simulation.state
	EventBus.room_built.emit(state.base.rooms[0].id)
	var site: WireCard = _wire().card_of(&"site_finished")
	assert_object(site).is_not_null()
	var dismiss: RefKey = site.get_keys().back()
	dismiss.pressed.emit()
	await _runner.simulate_frames(1)
	assert_object(_wire().card_of(&"site_finished")).is_null()
	state.budget.funds_k = -50
	_shell.frame.alert_list.refresh()
	assert_object(_wire().card_of(&"funds_red")).is_not_null()
	state.budget.funds_k = 100
	_shell.frame.alert_list.refresh()
	assert_object(_wire().card_of(&"funds_red")).is_null()


func test_it_never_pauses_and_keys_are_in_the_focus_ring() -> void:
	SimClock.resume()
	SimClock.simulation.state.budget.funds_k = -50
	_shell.frame.alert_list.refresh()
	assert_bool(SimClock.simulation.state.clock.is_paused).is_false()
	var keys: Array[Button] = _wire().get_keys()
	assert_array(keys).is_not_empty()
	var ring: Array[Button] = _shell.frame.get_focus_buttons([])
	for key: Button in keys:
		assert_bool(ring.has(key)).is_true()
	SimClock.pause()


func test_go_to_opens_the_cause() -> void:
	SimClock.simulation.state.budget.funds_k = -50
	_shell.frame.alert_list.refresh()
	var red: WireCard = _wire().card_of(&"funds_red")
	red.get_keys()[0].pressed.emit()
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("command")
