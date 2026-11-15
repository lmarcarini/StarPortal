## Tests for the v21 → v22 step (M4.8-02): a running conversation gets a phase, no cut-off
## and the conversation hold; the conversation slow goes; GameSetup puts one standing at a
## choice at CHOICE. A save without a conversation keeps its clock.
## Bible: docs/content/dialogue-screen.md section 7
extends GdUnitTestSuite


## A v21-shaped save running conv_kindred_first_hail at [param node], with the clock running
## and slowed by the conversation.
static func _v21(node: String) -> Dictionary:
	var state: GameState = GameState.new_game(3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var clock: Dictionary = data["clock"]
	clock["mode"] = "running"
	clock["slows"] = ["conversation", "dialling"]
	clock["overridden"] = ["conversation"]
	data["conversations"]["active"] = {
		"conversation": "conv_kindred_first_hail",
		"channel": "wormhole",
		"world": "world_lintel",
		"node": node,
		"node_tick": 0,
		"started_tick": 0,
		"path": [[node, -1]],
	}
	return {"format_version": 21, "tick": 0, "state": data}


static func _migrated(data: Dictionary) -> Dictionary:
	var result: Result = SaveMigrator.migrate(data)
	return result.value["state"]


func test_a_running_conversation_holds_the_clock() -> void:
	var state: Dictionary = _migrated(_v21("l1"))
	assert_array(GameState.validate_dict(state)).is_empty()
	var active: Dictionary = state["conversations"]["active"]
	assert_str(active["phase"]).is_equal("line")
	assert_bool(active["cut_off"]).is_false()
	var clock: Dictionary = state["clock"]
	assert_str(clock["mode"]).is_equal("held")
	assert_str(clock["mode_after_hold"]).is_equal("running")
	assert_array(clock["holds"]).is_equal(["conversation"])
	assert_array(clock["slows"]).is_equal(["dialling"])
	assert_array(clock["overridden"]).is_empty()


func test_a_conversation_at_a_choice_loads_at_choice() -> void:
	var state: GameState = GameState.from_dict(_migrated(_v21("ask")))
	assert_bool(GameSetup.build(state, GameDefs.from_registry(Registry)).is_ok).is_true()
	assert_int(state.conversations.active.phase).is_equal(ActiveConversation.Phase.CHOICE)
	var line: GameState = GameState.from_dict(_migrated(_v21("l1")))
	GameSetup.build(line, GameDefs.from_registry(Registry))
	assert_int(line.conversations.active.phase).is_equal(ActiveConversation.Phase.LINE)


func test_no_conversation_keeps_the_clock() -> void:
	var data: Dictionary = _v21("l1")
	data["state"]["conversations"]["active"] = {}
	var state: Dictionary = _migrated(data)
	assert_str(state["clock"]["mode"]).is_equal("running")
	assert_array(state["clock"]["holds"]).is_empty()
	assert_array(GameState.validate_dict(state)).is_empty()
