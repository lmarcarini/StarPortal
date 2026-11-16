## Tests for Hail (M4-09): offered only while locked to a world with a controller or people and
## no conversation running; starts the best wormhole conversation and meets the faction; with
## none, "No answer." in the Log and nothing else changes. The button follows can_hail.
## Bible: docs/content/m4-core-systems.md section 3 (Hail)
extends GdUnitTestSuite

const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")
const WORLD: StringName = &"world_lintel"
const KINDRED: StringName = &"faction_kindred"

var _state: GameState


func before_test() -> void:
	_state = StoryFixture.state()
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.gate.connected_world_id = WORLD


func _record() -> WorldRecord:
	return _state.galaxy.get_world(WORLD)


func test_can_hail_needs_a_faction_or_people() -> void:
	_record().controller = &""
	var facts: WorldFacts = WorldFactRules.facts_for_id(_state.galaxy, WORLD)
	var has_people: bool = facts.life == WorldDef.Life.PEOPLE
	assert_bool(GateQueries.can_hail(_state)).is_equal(has_people)
	_record().controller = KINDRED
	assert_bool(GateQueries.can_hail(_state)).is_true()
	_state.gate.mode = GateState.RingMode.IDLE
	assert_bool(GateQueries.can_hail(_state)).is_false()
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.conversations.active = ActiveConversation.new()
	assert_bool(GateQueries.can_hail(_state)).is_false()
	assert_str(String(HailCommand.new().validate(_state).error_code)).is_equal("cannot_hail")


func test_hail_starts_and_meets() -> void:
	_record().controller = KINDRED
	var def: ConversationDef = ConversationTests.make_def()
	_state.conversation_defs[def.id] = def
	var command := HailCommand.new()
	assert_bool(command.validate(_state).is_ok).is_true()
	command.apply(_state)
	assert_str(String(_state.conversations.active.conversation)).is_equal(String(def.id))
	assert_str(String(_state.conversations.active.world)).is_equal("world_lintel")
	assert_array(_state.factions.met).contains([KINDRED])


func test_no_answer_logs_and_changes_nothing() -> void:
	_record().controller = KINDRED
	_state.events.drain()
	var before: Dictionary = _state.to_dict()
	HailCommand.new().apply(_state)
	assert_dict(_state.to_dict()).is_equal(before)
	var events: Array[SimEvent] = _state.events.drain()
	assert_int(events.size()).is_equal(1)
	var entries: Array[LogEntry] = LogRules.entries_for(events[0].name, events[0].args, _state, 5)
	assert_str(str(entries[0].args["reason"])).is_equal("no_answer")
	TranslationServer.set_locale("en")
	assert_str(ArchiveLogRow.line_for(entries[0], _state)).contains("no answer")


func test_rail_key_follows_can_hail() -> void:
	_record().controller = KINDRED
	assert_bool(SendRailRules.hail(_state).shown).is_true()
	_record().controller = &""
	var facts: WorldFacts = WorldFactRules.facts_for_id(_state.galaxy, WORLD)
	facts.life = WorldDef.Life.NONE
	assert_bool(SendRailRules.hail(_state).shown).is_equal(GateQueries.can_hail(_state))
