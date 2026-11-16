## Regression tests for saves made mid-game (M4.9-18, #484): a save taken at each conversation
## phase, during an incursion warning and breach, mid mission order, while a team's call waits
## and while a team's return wormhole is open loads back, builds through GameSetup and keeps
## its state. The failing case was a team's incoming wormhole, saved with no conversation id
## and refused on load.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"
const SLOT: StringName = &"midgame"

var _service: SaveServiceScript
var _defs: GameDefs
var _state: GameState


func before_test() -> void:
	_service = SaveServiceScript.new()
	_service.saves_dir = (
		"user://test_saves_midgame_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	)
	_defs = GameDefs.from_registry(Registry)
	var loaded: Result = _service.load_file(SCENARIO, _defs)
	_state = loaded.value
	GameSetup.build(_state, _defs)


func after_test() -> void:
	var dir := DirAccess.open(_service.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_service.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(_service.saves_dir)
	_service.free()


## Saves, loads and builds the state; checks each step and the round trip.
func _assert_reloads() -> void:
	var before: Dictionary = _state.to_dict()
	var saved: Result = _service.save_game(_state, SLOT)
	assert_bool(saved.is_ok).override_failure_message(str(saved.error_code)).is_true()
	var loaded: Result = _service.load_game(SLOT, _defs)
	var detail: String = "%s %s" % [loaded.error_code, loaded.detail]
	assert_bool(loaded.is_ok).override_failure_message(detail).is_true()
	if not loaded.is_ok:
		return
	var state: GameState = loaded.value
	assert_object(state).is_not_null()
	var built: Result = GameSetup.build(state, _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	assert_dict(state.to_dict()).is_equal(before)


## A conversation whose start node reaches a Choice node by Lines only.
func _conversation_with_choice() -> StringName:
	for def: ConversationDef in _defs.conversations:
		var node: ConversationNodeDef = def.node(def.start)
		for step: int in 20:
			if node == null or node.kind == ConversationNodeDef.Kind.CHOICE:
				break
			node = def.node(node.next)
		if node != null and node.kind == ConversationNodeDef.Kind.CHOICE:
			return def.id
	return _defs.conversations[0].id


## Starts a conversation and moves it on until it is at [param phase] (or ended).
func _conversation_at(phase: ActiveConversation.Phase) -> void:
	(
		assert_bool(ConversationRules.start(_state, _conversation_with_choice(), &"phone", &""))
		. is_true()
	)
	for step: int in 40:
		var active: ActiveConversation = _state.conversations.active
		if active.phase == phase:
			return
		if active.phase == ActiveConversation.Phase.CHOICE:
			var shown: Array[Dictionary] = ConversationRules.choices(_state)
			var index: int = shown[0]["index"]
			ConversationRules.choose(_state, index)
		else:
			ConversationRules.advance(_state)
	assert_int(_state.conversations.active.phase).is_equal(phase)


func test_reloads_at_conversation_opening() -> void:
	_conversation_at(ActiveConversation.Phase.OPENING)
	_assert_reloads()


func test_reloads_at_conversation_line() -> void:
	_conversation_at(ActiveConversation.Phase.LINE)
	_assert_reloads()


func test_reloads_at_conversation_choice() -> void:
	_conversation_at(ActiveConversation.Phase.CHOICE)
	_assert_reloads()


func test_reloads_at_conversation_ended() -> void:
	_conversation_at(ActiveConversation.Phase.ENDED)
	_assert_reloads()


func test_reloads_during_incursion_warning() -> void:
	var def_id: StringName = _defs.incursions[0].id
	assert_bool(IncursionRules.start(_state, def_id).is_ok).is_true()
	_assert_reloads()


func test_reloads_during_incursion_breach() -> void:
	IncursionRules.start(_state, _defs.incursions[0].id)
	IncursionRules.breach(_state)
	_assert_reloads()


func test_reloads_mid_mission_order() -> void:
	var order: MissionOrder = _state.expedition.order
	order.world_id = _state.address_book.entries[0].world_id
	order.address = _state.galaxy.address_of(order.world_id, _state.galaxy.home().origin_glyph)
	order.enter(MissionOrder.Phase.WAIT_CHARGE, _state.clock.tick)
	_assert_reloads()


func test_reloads_while_a_team_call_waits() -> void:
	TeamContactRules.start_call(_state)
	assert_bool(_state.gate.has_incoming()).is_true()
	_assert_reloads()


func test_reloads_with_an_answered_faction_wormhole() -> void:
	_state.gate.incoming_faction = _defs.factions[0].id
	_state.gate.incoming_conversation = _defs.conversations[0].id
	_state.gate.incoming_until_tick = _state.clock.tick + 10
	RingControl.answer_incoming(_state.gate, _state.address_book.entries[0].world_id, 5)
	_assert_reloads()


func test_reloads_while_a_team_comes_home() -> void:
	TeamContactRules.open_return(_state, _state.address_book.entries[0].world_id)
	assert_bool(_state.gate.is_incoming_lock()).is_true()
	_assert_reloads()
