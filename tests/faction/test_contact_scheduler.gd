## Tests for faction-initiated contact (M4-10): cooldown, one pending per faction, once-only
## conversations, unmet factions never call, the channel by kind, priority, and missed phone
## calls costing Confidence once.
## Bible: docs/content/m4-core-systems.md section 2 (Faction-initiated contact)
extends GdUnitTestSuite

const KINDRED: StringName = &"faction_kindred"
const SENATE: StringName = &"faction_senate"

var _state: GameState
var _system := FactionSystem.new()


func _conversation(
	id: StringName, faction: StringName, channel: StringName, priority: int
) -> ConversationDef:
	var def := ConversationDef.new()
	def.id = id
	def.faction = faction
	def.channels = [channel]
	def.priority = priority
	_state.conversation_defs[id] = def
	return def


func _faction(id: StringName, kind: StringName, contacts: Array[StringName]) -> FactionDef:
	var faction := FactionDef.new()
	faction.id = id
	faction.kind = kind
	faction.contacts = contacts
	_state.faction_defs[id] = faction
	return faction


func before_test() -> void:
	_state = StoryFixture.state()
	_state.faction_defs.clear()
	_conversation(&"conv_low", KINDRED, &"incoming", 1)
	_conversation(&"conv_high", KINDRED, &"incoming", 5).once = true
	_conversation(&"conv_wrong_channel", KINDRED, &"wormhole", 9)
	_conversation(&"conv_call", SENATE, &"phone", 0)
	_faction(KINDRED, &"alien", [&"conv_low", &"conv_high", &"conv_wrong_channel"])
	_faction(SENATE, &"earth", [&"conv_call"])
	_state.clock.tick = 10 * TimeMath.TICKS_PER_DAY


func _day() -> void:
	_system.on_day(_state)


func test_unmet_factions_never_contact() -> void:
	_day()
	assert_array(_state.factions.pending).is_empty()


func test_priority_channel_and_one_pending() -> void:
	_state.factions.met.append(KINDRED)
	_state.factions.met.append(SENATE)
	_day()
	assert_int(_state.factions.pending.size()).is_equal(2)
	var first: PendingContact = _state.factions.pending[0]
	assert_str(String(first.conversation)).is_equal("conv_high")
	assert_str(String(first.channel)).is_equal("incoming")
	assert_int(first.expires_tick).is_equal(-1)
	var second: PendingContact = _state.factions.pending[1]
	assert_str(String(second.conversation)).is_equal("conv_call")
	assert_str(String(second.channel)).is_equal("phone")
	assert_int(second.expires_tick).is_equal(12 * TimeMath.TICKS_PER_DAY)
	assert_int(ContactRules.next_pending(_state, &"incoming")).is_equal(0)
	assert_int(ContactRules.next_pending(_state, &"phone")).is_equal(1)
	assert_int(ContactRules.next_pending(_state, &"wormhole")).is_equal(-1)
	_state.clock.tick += 10 * TimeMath.TICKS_PER_DAY
	_state.factions.pending.remove_at(0)
	_day()
	assert_int(_state.factions.pending.size()).is_equal(2)


func test_cooldown_and_once() -> void:
	_state.factions.met.append(KINDRED)
	_day()
	_state.factions.pending.clear()
	_state.conversations.count[&"conv_high"] = 1
	_state.clock.tick += 3 * TimeMath.TICKS_PER_DAY
	_day()
	assert_array(_state.factions.pending).is_empty()
	_state.clock.tick += TimeMath.TICKS_PER_DAY
	_day()
	assert_int(_state.factions.pending.size()).is_equal(1)
	assert_str(String(_state.factions.pending[0].conversation)).is_equal("conv_low")


func test_conditions_must_hold() -> void:
	_state.factions.met.append(KINDRED)
	var gate := StandingAtLeastCondition.new()
	gate.faction = KINDRED
	gate.amount = 50
	_state.conversation_defs[&"conv_high"].conditions.append(gate)
	_state.conversation_defs[&"conv_low"].conditions.append(gate)
	_day()
	assert_array(_state.factions.pending).is_empty()


func test_missed_call_costs_confidence_once() -> void:
	_state.factions.met.append(SENATE)
	_day()
	var confidence: int = _state.committee.confidence
	_state.clock.tick += TimeMath.TICKS_PER_DAY
	ContactRules.expire_calls(_state)
	assert_int(_state.factions.pending.size()).is_equal(1)
	_state.clock.tick += TimeMath.TICKS_PER_DAY
	_state.events.drain()
	ContactRules.expire_calls(_state)
	ContactRules.expire_calls(_state)
	assert_array(_state.factions.pending).is_empty()
	assert_int(_state.committee.confidence).is_equal(confidence - 10)
	var names: Array[StringName] = StoryFixture.event_names(_state)
	assert_int(names.count(&"call_missed")).is_equal(1)
