## Tests for ModifierRules (M4-22): research and housed, powered artefacts as sources, sums and
## the percent clamp, an unpowered or unbuilt room giving nothing, and the cache matching a
## fresh compute after each kind of change and after a load, with no rebuild while nothing
## changes.
## Bible: docs/content/m4-core-systems.md section 6
extends GdUnitTestSuite

var _state: GameState
var _room: RoomState


static func _modifier(key: StringName, amount: int) -> ModifierEffect:
	var modifier := ModifierEffect.new()
	modifier.key = key
	modifier.amount = amount
	return modifier


func before_test() -> void:
	_state = StoryFixture.state()
	var project := ResearchDef.new()
	project.id = &"project_speed"
	project.effects = [_modifier(&"research_speed_pct", 20), _modifier(&"allocation_k", 50)]
	_state.research_defs[project.id] = project
	var relic := ArtefactDef.new()
	relic.id = &"artefact_relic"
	relic.modifiers = [_modifier(&"research_speed_pct", 300), _modifier(&"wormhole_minutes", 10)]
	_state.artefact_defs[relic.id] = relic
	_room = _state.base.rooms[0]


func _house() -> ArtefactRecord:
	var uid: int = StoryRulesItems.give_artefact(_state, &"artefact_relic")
	var record: ArtefactRecord = _state.artefacts.items[uid]
	record.room_uid = String(_room.id).trim_prefix("room_").to_int()
	record.state = ArtefactRecord.ArtefactState.HOUSED
	return record


func _assert_fresh() -> void:
	assert_dict(ModifierRules.totals(_state)).is_equal(ModifierRules.compute(_state))


func test_research_source() -> void:
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(0)
	_state.research.done.append(&"project_speed")
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(20)
	assert_int(ModifierRules.total(_state, &"allocation_k")).is_equal(50)
	assert_float(ModifierRules.percent(_state, &"research_speed_pct", 10.0)).is_equal(12.0)


func test_artefact_source_sum_and_clamp() -> void:
	_state.research.done.append(&"project_speed")
	_house()
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(300)
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(10)
	_state.artefact_defs[&"artefact_relic"].modifiers = [
		_modifier(&"research_speed_pct", -500), _modifier(&"wormhole_minutes", -500)
	]
	_state.modifiers.signature = []
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(-90)
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(-500)


func test_unpowered_unbuilt_and_holding_give_nothing() -> void:
	var record: ArtefactRecord = _house()
	_room.powered_on = false
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(0)
	_room.powered_on = true
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(10)
	_room.build_ticks_left = 5
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(0)
	_room.build_ticks_left = 0
	record.room_uid = ArtefactRecord.IN_HOLDING
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(0)
	record.room_uid = ArtefactRecord.AT_GATE
	_assert_fresh()


func test_cache_follows_changes_and_does_not_rebuild_idle() -> void:
	_assert_fresh()
	var rebuilds: int = _state.modifiers.rebuilds
	for index: int in 50:
		ModifierRules.total(_state, &"research_speed_pct")
	assert_int(_state.modifiers.rebuilds).is_equal(rebuilds)
	_state.research.done.append(&"project_speed")
	_assert_fresh()
	var record: ArtefactRecord = _house()
	_assert_fresh()
	_room.powered_on = false
	_assert_fresh()
	_state.base.remove_room(_room.id)
	_assert_fresh()
	record.room_uid = ArtefactRecord.IN_HOLDING
	_assert_fresh()


func test_rebuilt_after_load() -> void:
	_state.research.done.append(&"project_speed")
	_house()
	var before: Dictionary[StringName, int] = ModifierRules.totals(_state).duplicate()
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	loaded.research_defs = _state.research_defs
	loaded.artefact_defs = _state.artefact_defs
	assert_dict(ModifierRules.totals(loaded)).is_equal(before)
