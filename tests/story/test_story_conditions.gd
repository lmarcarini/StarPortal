## Tests for StoryRules.check (M4-05): every condition class true and false.
## Bible: docs/content/m4-core-systems.md section 1
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = StoryFixture.state()


func _check(condition: ConditionDef) -> bool:
	return StoryRules.check(_state, condition)


func test_flag_is() -> void:
	var condition := FlagIsCondition.new()
	condition.flag = &"met_elder"
	assert_bool(_check(condition)).is_false()
	_state.flags[&"met_elder"] = true
	assert_bool(_check(condition)).is_true()
	condition.value = 3
	_state.flags[&"met_elder"] = 3.0
	assert_bool(_check(condition)).is_true()
	_state.flags[&"met_elder"] = true
	assert_bool(_check(condition)).is_false()
	condition.value = false
	_state.flags.erase(&"met_elder")
	assert_bool(_check(condition)).is_true()


func test_standing_at_least_and_below() -> void:
	var at_least := StandingAtLeastCondition.new()
	at_least.faction = &"faction_kindred"
	at_least.amount = 25
	var below := StandingBelowCondition.new()
	below.faction = &"faction_kindred"
	below.amount = 25
	_state.factions.standing[&"faction_kindred"] = 24
	assert_bool(_check(at_least)).is_false()
	assert_bool(_check(below)).is_true()
	_state.factions.standing[&"faction_kindred"] = 25
	assert_bool(_check(at_least)).is_true()
	assert_bool(_check(below)).is_false()
	at_least.faction = FactionRules.COMMITTEE
	at_least.amount = 50
	_state.committee.confidence = 500
	assert_bool(_check(at_least)).is_true()


func test_faction_met() -> void:
	var condition := FactionMetCondition.new()
	condition.faction = &"faction_kindred"
	assert_bool(_check(condition)).is_false()
	FactionRules.meet(_state, &"faction_kindred")
	assert_bool(_check(condition)).is_true()


func test_research_done() -> void:
	var condition := ResearchDoneCondition.new()
	condition.project = &"later_capacitor_lattice"
	assert_bool(_check(condition)).is_false()
	_state.research.done.append(&"later_capacitor_lattice")
	assert_bool(_check(condition)).is_true()


func test_has_artefact_any_place() -> void:
	var condition := HasArtefactCondition.new()
	condition.artefact = &"artefact_loom"
	assert_bool(_check(condition)).is_false()
	var uid: int = StoryRulesItems.give_artefact(_state, &"artefact_loom")
	_state.artefacts.items[0].room_uid = ArtefactRecord.AT_GATE
	assert_int(uid).is_equal(0)
	assert_bool(_check(condition)).is_true()


func test_world_status_at_least() -> void:
	var condition := WorldStatusAtLeastCondition.new()
	condition.world = &"world_lintel"
	condition.status = WorldStatusAtLeastCondition.WorldStatus.PROBED
	_state.worlds.statuses[&"world_lintel"] = WorldsState.WorldStatus.LOCKED
	assert_bool(_check(condition)).is_false()
	_state.worlds.statuses[&"world_lintel"] = WorldsState.WorldStatus.SURVEYED
	assert_bool(_check(condition)).is_true()


func test_request_is_reads_the_newest() -> void:
	var condition := RequestIsCondition.new()
	condition.request = &"request_test"
	condition.state = RequestIsCondition.RequestState.OFFERED
	assert_bool(_check(condition)).is_false()
	StoryRulesItems.offer_request(_state, &"request_test")
	assert_bool(_check(condition)).is_true()
	_state.requests.items[0].state = RequestRecord.RequestState.LAPSED
	assert_bool(_check(condition)).is_false()
	StoryRulesItems.offer_request(_state, &"request_test")
	assert_bool(_check(condition)).is_true()


func test_no_dial_since() -> void:
	var condition := NoDialSinceCondition.new()
	condition.flag = &"closed_since"
	_state.clock.tick = 1000
	_state.flags[&"closed_since"] = 1000
	assert_bool(_check(condition)).is_true()
	_state.gate.dial_started_tick = 999
	assert_bool(_check(condition)).is_true()
	_state.gate.dial_started_tick = 1000
	assert_bool(_check(condition)).is_false()


func test_failing_and_check_all() -> void:
	var met := FactionMetCondition.new()
	met.faction = &"faction_kindred"
	var flag := FlagIsCondition.new()
	flag.flag = &"x"
	flag.value = false
	var conditions: Array[ConditionDef] = [met, flag]
	assert_bool(StoryRules.check_all(_state, conditions)).is_false()
	assert_array(StoryRules.failing(_state, conditions)).is_equal([met])
	var none: Array[ConditionDef] = []
	assert_bool(StoryRules.check_all(_state, none)).is_true()


func test_reason_lines() -> void:
	TranslationServer.set_locale("en")
	var condition := StandingAtLeastCondition.new()
	condition.faction = &"faction_kindred"
	condition.amount = 25
	assert_str(StoryText.reason(condition)).is_equal("Requires faction_kindred standing 25")
	var world := WorldStatusAtLeastCondition.new()
	world.world = &"world_lintel"
	world.status = WorldStatusAtLeastCondition.WorldStatus.PROBED
	assert_str(StoryText.reason(world)).contains("PROBED")
