## Tests for the M4 state sections (M4-03): factions, conversations, requests, artefacts, the
## research queue and revealed list and the incoming wormhole. Round trips are identical and
## validate_dict rejects each kind of malformed data.
## Bible: docs/content/m4-core-systems.md section 9
extends GdUnitTestSuite


func _filled() -> GameState:
	var state := GameState.new_game(7)
	state.clock.tick = 5000
	state.factions.standing[&"faction_kindred"] = 25
	state.factions.met.append(&"faction_kindred")
	state.factions.causes[&"faction_kindred"] = [{"tick": 100, "delta": 5, "key": &"CAUSE_GIFT"}]
	var contact := PendingContact.new()
	contact.faction = &"faction_kindred"
	contact.conversation = &"conv_gift"
	contact.channel = &"incoming"
	contact.since_tick = 4000
	state.factions.pending.append(contact)
	state.factions.last_contact_tick[&"faction_kindred"] = 3000
	state.factions.used.append(&"conv_first")
	var active := ActiveConversation.new()
	active.conversation = &"conv_gift"
	active.world = &"world_hearth"
	active.node = &"n2"
	active.node_tick = 4990
	active.phase = ActiveConversation.Phase.CHOICE
	active.path = [[&"n1", -1], [&"n2", 1]]
	state.conversations.active = active
	var transcript := TranscriptRecord.new()
	transcript.uid = 0
	transcript.conversation = &"conv_first"
	transcript.channel = &"phone"
	transcript.tick = 200
	transcript.path = [[&"n1", 0]]
	transcript.cut_off = true
	state.conversations.transcripts.append(transcript)
	state.conversations.count[&"conv_first"] = 1
	state.conversations.next_uid = 1
	var request := RequestRecord.new()
	request.uid = 3
	request.request = &"request_survey"
	request.state = RequestRecord.RequestState.ACTIVE
	request.offered_tick = 1000
	request.accepted_tick = 1100
	request.deadline_tick = 99000
	state.requests.items.append(request)
	state.requests.next_uid = 4
	var artefact := ArtefactRecord.new()
	artefact.uid = 0
	artefact.artefact = &"artefact_relic"
	artefact.room_uid = ArtefactRecord.AT_GATE
	artefact.arrived_tick = 4500
	state.artefacts.items.append(artefact)
	state.artefacts.next_uid = 1
	state.research.ensure_bench(&"room_1").queue.append(&"research_a")
	state.research.revealed.append(&"research_hidden")
	state.gate.incoming_faction = &"faction_kindred"
	state.gate.incoming_conversation = &"conv_gift"
	state.gate.incoming_until_tick = 5005
	return state


func _json(state: GameState) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state.to_dict()))


## A filled state survives a JSON round trip identically and validates.
func test_round_trip_is_identical() -> void:
	var state: GameState = _filled()
	var data: Dictionary = _json(state)
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	assert_str(JSON.stringify(loaded.to_dict())).is_equal(JSON.stringify(state.to_dict()))
	assert_int(loaded.requests.items[0].state).is_equal(RequestRecord.RequestState.ACTIVE)
	assert_int(loaded.artefacts.items[0].room_uid).is_equal(ArtefactRecord.AT_GATE)
	var node: StringName = loaded.conversations.active.path[1][0]
	assert_str(String(node)).is_equal("n2")
	assert_bool(loaded.gate.has_incoming()).is_true()


## A new game has empty sections that validate.
func test_new_game_sections_are_empty() -> void:
	var state := GameState.new_game(1)
	assert_array(GameState.validate_dict(_json(state))).is_empty()
	assert_object(state.conversations.active).is_null()
	assert_bool(state.gate.has_incoming()).is_false()


## FactionsState.starting sets standings (not the Committee's) and meets Earth factions.
func test_starting_factions() -> void:
	var committee := FactionDef.new()
	committee.id = &"faction_committee"
	committee.kind = &"earth"
	committee.uses_confidence = true
	committee.start_standing = 50
	var kindred := FactionDef.new()
	kindred.id = &"faction_kindred"
	kindred.start_standing = -10
	var defs: Array[FactionDef] = [committee, kindred]
	var factions: FactionsState = FactionsState.starting(defs)
	assert_dict(factions.standing).is_equal({&"faction_kindred": -10})
	assert_array(factions.met).is_equal([&"faction_committee"])


func _errors_after(path: Array, value: Variant) -> Array[String]:
	var data: Dictionary = _json(_filled())
	var target: Variant = data
	for index: int in path.size() - 1:
		target = target[path[index]]
	target[path[-1]] = value
	return GameState.validate_dict(data)


## Each malformed section is rejected.
func test_malformed_sections_are_rejected() -> void:
	var cases: Array = [
		[["factions", "standing", "faction_kindred"], 150],
		[["factions", "standing", "faction_kindred"], "high"],
		[["factions", "met"], ["a", "a"]],
		[["factions", "causes", "faction_kindred"], [{"tick": 1}]],
		[["factions", "pending", 0, "channel"], "carrier pigeon"],
		[["factions", "last_contact_tick", "faction_kindred"], -5],
		[["factions", "used"], "conv_first"],
		[["conversations", "active", "path"], [["n1"]]],
		[["conversations", "active", "channel"], "radio"],
		[["conversations", "transcripts", 0, "cut_off"], "yes"],
		[["conversations", "next_uid"], 0],
		[["conversations", "count", "conv_first"], 1.5],
		[["requests", "items", 0, "state"], 6],
		[["requests", "items", 0, "state"], -1],
		[["requests", "items", 0, "accepted_tick"], -2],
		[["requests", "next_uid"], 2],
		[["artefacts", "items", 0, "state"], 3],
		[["artefacts", "items", 0, "room_uid"], -4],
		[["artefacts", "items", 0, "uid"], 9007199254740994.0],
		[["research", "benches"], {"r": {"active": "", "ticks_done": 0, "queue": ["a", ""]}}],
		[["research", "revealed"], 5],
		[["gate", "incoming"], {"faction": "x"}],
		[["gate", "incoming"], []],
	]
	for case: Array in cases:
		var path: Array = case[0]
		var message: String = "accepted %s = %s" % [str(path), str(case[1])]
		assert_array(_errors_after(path, case[1])).override_failure_message(message).is_not_empty()


## Duplicate uids are rejected.
func test_duplicate_uids_are_rejected() -> void:
	var data: Dictionary = _json(_filled())
	var requests: Dictionary = data["requests"]
	var items: Array = requests["items"]
	var first: Dictionary = items[0]
	items.append(first.duplicate())
	requests["next_uid"] = 10
	var errors: Array[String] = GameState.validate_dict(data)
	assert_str("\n".join(errors)).contains("duplicate uid 3")


## Ticks later than the clock are rejected; a future deadline is fine.
func test_future_ticks_are_rejected() -> void:
	assert_array(_errors_after(["requests", "items", 0, "deadline_tick"], 999999)).is_empty()
	for path: Array in [
		["requests", "items", 0, "offered_tick"],
		["artefacts", "items", 0, "arrived_tick"],
		["conversations", "transcripts", 0, "tick"],
		["conversations", "active", "node_tick"],
		["factions", "pending", 0, "since_tick"],
		["factions", "last_contact_tick", "faction_kindred"],
	]:
		assert_array(_errors_after(path, 6000)).override_failure_message(str(path)).is_not_empty()


## A missing section is rejected.
func test_missing_section_is_rejected() -> void:
	var data: Dictionary = _json(_filled())
	data.erase("artefacts")
	assert_array(GameState.validate_dict(data)).contains(["missing 'artefacts'"])
