## Tests for the saved probe state, target states and the good threat's reasons: round trips
## through JSON, validation of bad data, and reasons stored only with a GOOD threat.
## Bible: docs/content/m3-beyond-the-ring.md section 2 and section 9 (saves)
extends GdUnitTestSuite


func _round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	return parsed


func _busy_probes() -> ProbesState:
	var probes := ProbesState.new()
	probes.canister_world_id = &"world_a"
	probes.canister_ticks_left = 4
	probes.moth = MothRun.create(&"world_a")
	probes.moth.battery_left = 11
	probes.moth.scan = MothRules.Scan.CLOSE_LOOK
	probes.moth.target_id = &"iron_object"
	probes.moth.scan_ticks_left = 3
	probes.moth.done.append("look_around")
	probes.rack = 0
	probes.reorders.append(1500)
	probes.add_photo(&"world_a", "sky", &"", 12)
	probes.ring_scanned[&"world_a"] = true
	return probes


## A busy probe state survives a JSON round trip and validates.
func test_round_trip() -> void:
	var data: Dictionary = _round_trip(_busy_probes().to_dict())
	assert_array(ProbesState.validate_dict(data)).is_empty()
	assert_dict(ProbesState.from_dict(data).to_dict()).is_equal(_busy_probes().to_dict())
	assert_array(ProbesState.validate_dict(ProbesState.new().to_dict())).is_empty()


## Bad data is reported: half-set canister, scan ticks with no scan, too many drones.
func test_validation() -> void:
	var data: Dictionary = _busy_probes().to_dict()
	data["canister_world_id"] = ""
	assert_array(ProbesState.validate_dict(data)).is_not_empty()
	data = _busy_probes().to_dict()
	data["moth"]["scan"] = ""
	assert_array(ProbesState.validate_dict(data)).is_not_empty()
	data = _busy_probes().to_dict()
	data["rack"] = 1
	assert_array(ProbesState.validate_dict(data)).is_not_empty()
	data = _busy_probes().to_dict()
	data["photos"] = [{"world_id": "a", "kind": "selfie", "target_id": "", "tick": 1}]
	assert_array(ProbesState.validate_dict(data)).is_not_empty()


## Target states round-trip, only go up and validate their names.
func test_target_states() -> void:
	var states := TargetStates.new()
	assert_bool(states.raise(&"w", &"t", TargetStates.State.RECOVERED)).is_true()
	assert_bool(states.raise(&"w", &"t", TargetStates.State.RECOVERABLE)).is_false()
	var data: Dictionary = _round_trip(states.to_dict())
	assert_dict(data).is_equal({"w": {"t": "recovered"}})
	assert_int(TargetStates.from_dict(data).state_of(&"w", &"t")).is_equal(
		TargetStates.State.RECOVERED
	)
	assert_array(TargetStates.validate_dict({"w": {"t": "none"}})).is_not_empty()


## A team survey's GOOD threat stores its reasons in the world report, which survive saving;
## reasons on any other entry are refused by validation.
func test_good_threat_carries_reasons() -> void:
	var state := GameState.new_game(1)
	var facts := WorldFacts.new()
	facts.threat = WorldDef.Threat.HIGH
	facts.life = WorldDef.Life.ANIMALS
	assert_bool(WorldProgress.raise_threat_good(state, &"w", &"team", facts)).is_true()
	var report: WorldReport = state.worlds.report_of(&"w")
	assert_array(report.threat_reasons()).contains_exactly(
		[&"THREAT_REASON_GUARDED", &"THREAT_REASON_ANIMALS"]
	)
	var data: Dictionary = _round_trip(report.to_dict())
	assert_array(WorldReport.validate_dict("w", data)).is_empty()
	assert_array(WorldReport.from_dict(data).threat_reasons()).is_equal(report.threat_reasons())
	data["threat"]["confidence"] = "fair"
	assert_array(WorldReport.validate_dict("w", data)).is_not_empty()
	assert_array(ThreatReasons.of(WorldFacts.new())).contains_exactly([&"THREAT_REASON_NONE"])
