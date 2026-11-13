## Tests for FactionRules (M4-04): bands, the Committee on Confidence, clamping, the cause cap,
## unknown factions and meeting.
## Bible: docs/content/m4-core-systems.md section 2
extends GdUnitTestSuite

const KINDRED: StringName = &"faction_kindred"

var _state: GameState


func before_test() -> void:
	_state = GameState.new_game(1)
	_state.factions.standing[KINDRED] = 0


func _attitude_at(value: int) -> FactionRules.Attitude:
	_state.factions.standing[KINDRED] = value
	return FactionRules.attitude(_state, KINDRED)


func test_band_edges() -> void:
	var cases: Dictionary[int, int] = {
		-100: FactionRules.Attitude.HOSTILE,
		-50: FactionRules.Attitude.HOSTILE,
		-49: FactionRules.Attitude.UNFRIENDLY,
		-10: FactionRules.Attitude.UNFRIENDLY,
		-9: FactionRules.Attitude.NEUTRAL,
		24: FactionRules.Attitude.NEUTRAL,
		25: FactionRules.Attitude.FRIENDLY,
		59: FactionRules.Attitude.FRIENDLY,
		60: FactionRules.Attitude.ALLIED,
		100: FactionRules.Attitude.ALLIED,
	}
	for value: int in cases:
		assert_int(_attitude_at(value)).override_failure_message(str(value)).is_equal(cases[value])


func test_committee_bands_read_confidence() -> void:
	var cases: Dictionary[int, int] = {
		0: FactionRules.Attitude.UNFRIENDLY,
		299: FactionRules.Attitude.UNFRIENDLY,
		300: FactionRules.Attitude.NEUTRAL,
		699: FactionRules.Attitude.NEUTRAL,
		700: FactionRules.Attitude.FRIENDLY,
	}
	for tenths: int in cases:
		_state.committee.confidence = tenths
		assert_int(FactionRules.attitude(_state, FactionRules.COMMITTEE)).is_equal(cases[tenths])
	_state.committee.confidence = 615
	assert_int(FactionRules.standing(_state, FactionRules.COMMITTEE)).is_equal(61)


func test_change_clamps_and_posts() -> void:
	_state.factions.standing[KINDRED] = 95
	assert_int(FactionRules.change(_state, KINDRED, 10, &"CAUSE_GIFT")).is_equal(5)
	assert_int(FactionRules.standing(_state, KINDRED)).is_equal(100)
	assert_int(FactionRules.change(_state, KINDRED, 3, &"CAUSE_GIFT")).is_equal(0)
	assert_int(FactionRules.change(_state, KINDRED, -250, &"CAUSE_GIFT")).is_equal(-200)
	assert_int(FactionRules.standing(_state, KINDRED)).is_equal(-100)
	var names: Array = _state.events.drain().map(
		func(event: SimEvent) -> StringName: return event.name
	)
	assert_array(names).is_equal([&"standing_changed", &"standing_changed"])


func test_causes_are_capped_at_ten() -> void:
	for index: int in 12:
		_state.clock.tick = index
		FactionRules.change(_state, KINDRED, 1, StringName("CAUSE_%d" % index))
	var causes: Array = _state.factions.causes[KINDRED]
	assert_int(causes.size()).is_equal(10)
	var first: Dictionary = causes[0]
	assert_str(str(first["key"])).is_equal("CAUSE_2")
	assert_int(first["delta"]).is_equal(1)


func test_committee_change_moves_confidence() -> void:
	_state.committee.confidence = 500
	var causes_before: int = _state.committee.causes.size()
	assert_int(FactionRules.change(_state, FactionRules.COMMITTEE, -2, &"CAUSE_IGNORED")).is_equal(
		-2
	)
	assert_int(_state.committee.confidence).is_equal(480)
	assert_int(_state.committee.causes.size()).is_equal(causes_before + 1)
	var cause: ConfidenceCause = _state.committee.causes[-1]
	assert_str(String(cause.cause)).is_equal("story")
	assert_str(String(cause.subject)).is_equal("CAUSE_IGNORED")
	assert_int(cause.change).is_equal(-20)
	assert_bool(_state.factions.standing.has(FactionRules.COMMITTEE)).is_false()


func test_unknown_faction_changes_nothing() -> void:
	var before: Dictionary = _state.to_dict()
	assert_int(FactionRules.change(_state, &"faction_nobody", 5, &"X")).is_equal(0)
	assert_dict(_state.to_dict()).is_equal(before)
	assert_int(FactionRules.standing(_state, &"faction_nobody")).is_equal(0)


func test_meet_once_and_log_line() -> void:
	assert_bool(FactionRules.meet(_state, KINDRED)).is_true()
	assert_bool(FactionRules.meet(_state, KINDRED)).is_false()
	assert_array(_state.factions.met).contains([KINDRED])
	var events: Array[SimEvent] = _state.events.drain()
	assert_int(events.size()).is_equal(1)
	var entries: Array[LogEntry] = LogRules.entries_for(events[0].name, events[0].args, _state, 10)
	assert_str(String(entries[0].kind)).is_equal("faction")
	assert_str(str(entries[0].args["faction_id"])).is_equal("faction_kindred")


func test_attitude_keys_are_translated() -> void:
	for key: StringName in FactionRules.ATTITUDE_KEYS:
		TranslationServer.set_locale("en")
		assert_str(TranslationServer.translate(key)).is_not_equal(String(key))
		TranslationServer.set_locale("pt_BR")
		assert_str(TranslationServer.translate(key)).is_not_equal(String(key))
	TranslationServer.set_locale("en")
	assert_str(FactionRules.attitude_key(FactionRules.Attitude.ALLIED)).is_equal("ATTITUDE_ALLIED")
