## Tests for artefact hazards (M4-27): a daily roll outside containment, 0 % never, 100 %
## always, Containment never, deterministic with the seed, and the Log line.
## Bible: docs/content/m4-core-systems.md section 5 (Hazard)
extends GdUnitTestSuite

var _state: GameState
var _def: ArtefactDef


func before_test() -> void:
	_state = ConstructionFixture.unlock_all(ConstructionFixture.grown())
	_state.budget.funds_k = 0
	_def = ArtefactDef.new()
	_def.id = &"artefact_hot"
	_def.storage = &"containment"
	var money := ChangeMoneyEffect.new()
	money.amount_k = -10
	_def.hazard = [money]
	_state.artefact_defs[_def.id] = _def
	StoryRulesItems.give_artefact(_state, _def.id)
	_state.events.drain()


func _days(count: int) -> int:
	var system := ArtefactSystem.new()
	var hits: int = 0
	for day: int in count:
		system.on_day(_state)
		for event: SimEvent in _state.events.drain():
			if event.name == &"artefact_hazard":
				hits += 1
	return hits


func test_zero_and_hundred() -> void:
	_def.hazard_chance_pct = 0
	assert_int(_days(50)).is_equal(0)
	_def.hazard_chance_pct = 100
	assert_int(_days(5)).is_equal(5)
	assert_int(_state.budget.funds_k).is_equal(-50)


func test_containment_never() -> void:
	_def.hazard_chance_pct = 100
	var room: RoomState = _state.base.add_room(&"room_containment", 2, Vector2i(10, 10))
	ArtefactRules.move(_state, 0, ArtefactRules.room_uid_of(room.id))
	assert_int(_days(10)).is_equal(0)
	var vault: RoomState = _state.base.add_room(&"room_artefact_vault", 2, Vector2i(20, 10))
	ArtefactRules.move(_state, 0, ArtefactRules.room_uid_of(vault.id))
	assert_int(_days(3)).is_equal(3)


func test_deterministic() -> void:
	_def.hazard_chance_pct = 30
	var first: int = _days(100)
	assert_int(first).is_between(10, 50)
	before_test()
	_def.hazard_chance_pct = 30
	assert_int(_days(100)).is_equal(first)


func test_log_line() -> void:
	TranslationServer.set_locale("en")
	var entries: Array[LogEntry] = LogRules.entries_for(
		&"artefact_hazard", [&"artefact_hot"], _state, 1
	)
	assert_str(ArchiveLogRow.line_for(entries[0], _state)).contains("artefact_hot")
