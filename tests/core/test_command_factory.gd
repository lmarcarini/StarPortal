## Tests for CommandFactory: rebuilding every registered command type from its to_dict(),
## failures on unknown or malformed data, and the resettable registry.
## Bible: technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite


## A test-only command type, registered and then removed by reset().
class PingCommand:
	extends Command

	static func from_dict(_data: Dictionary) -> Result:
		return Result.ok(PingCommand.new())

	func get_type() -> StringName:
		return &"ping"

	func validate(_state: GameState) -> CommandResult:
		return CommandResult.ok()

	func apply(_state: GameState) -> void:
		pass

	func to_dict() -> Dictionary:
		return {"type": "ping"}


func after_test() -> void:
	CommandFactory.reset()


## One sample command per built-in type. Add one here for every new registered type.
func _samples() -> Array[Command]:
	return [
		SetFlagCommand.create(&"met_kessler", true),
		SetFlagCommand.create(&"dial_attempts", 7),
		SetFlagCommand.create(&"last_world", "P3X-118"),
		DialCommand.create(GateAddress.create([3, 17, 0, 22, 9, 14, 30], 5)),
		CloseWormholeCommand.new(),
		ChooseOptionCommand.new(2),
		EndConversationCommand.new(),
		HailCommand.new(),
		QueueResearchCommand.new(&"lift_shaft", 1),
		UnqueueResearchCommand.new(&"lift_shaft"),
		HouseArtefactCommand.new(1, 2),
		UnhouseArtefactCommand.new(1),
		RetrieveArtefactCommand.new(1),
		DebugStoryCommand.create(&"flag", &"x", "1"),
		DebugCheatCommand.create(&"funds", &"", 5),
		OverrideSlowCommand.create(),
		OperateGateCommand.new(),
		StandByCommand.new(),
		BuildDoorCommand.create(1, Vector2i(2, 3)),
		RemoveDoorCommand.create(1, Vector2i(2, 3)),
		SetDoorCommand.create(1, Vector2i(2, 3), DoorState.Mode.SEALED),
		RepairRoomCommand.create(&"room_3"),
		InstallCommand.create(&"room_3", &"installation_x"),
		RemoveInstallationCommand.create(&"room_3", &"installation_x"),
		OrderSquadCommand.create(&"room_9", SquadState.Order.MOVE, Vector3i(1, 2, 1)),
		AcceptRequestCommand.new(3),
		DeclineRequestCommand.new(4),
		AnswerCallCommand.new(),
		AnswerIncomingCommand.new(),
		IgnoreIncomingCommand.new(),
		DeliverDocumentCommand.create(&"doc_survey_note_1958"),
		MarkDocumentReadCommand.create(&"doc_survey_note_1958"),
		NoteAddressCommand.create("3-17-0-22-9-14-30-5", "dead world, safe"),
		SwitchRoomCommand.create(&"room_4", false),
		SetChargeRateCommand.create(&"room_9", 26),
		ReadConsoleCommand.new(),
		ExtendPoleCameraCommand.new(),
		PlaceRoomCommand.create(&"room_research_lab", 2, Vector2i(3, 4), true),
		PaintCorridorCommand.create(1, [Vector2i(1, 1), Vector2i(2, 1)]),
		CancelBuildCommand.create(&"room_7"),
		DemolishRoomCommand.create(&"room_3"),
		DigLevelCommand.new(),
		StartResearchCommand.create(&"bank_array"),
		CancelResearchCommand.new(),
		AssignStaffCommand.create(&"person_1", &"room_2"),
		UnassignStaffCommand.create(&"person_2"),
		HireCommand.create(&"candidate_1"),
		DismissCommand.create(&"person_2"),
		RaiseWorldStatusCommand.create(&"world_0001", WorldsState.WorldStatus.PROBED),
		RaiseWorldFactCommand.create(
			WorldProgress.FactChange.create(
				&"world_0001", WorldReport.Fact.LIFE, WorldReport.Confidence.FAIR, &"moth"
			)
		),
		LaunchCanisterCommand.new(),
		LaunchMothCommand.new(),
		MothScanCommand.create(MothRules.Scan.CLOSE_LOOK, &"iron_object"),
		MothScanCommand.create(MothRules.Scan.RECALL),
		PlanExpeditionCommand.create(
			ExpeditionState.Objective.RECOVER,
			&"world_stillwater",
			&"iron_object",
			{"leader": "person_1", "scientist": "person_2", "soldier": "p3", "specialist": "p4"}
		),
		SendTeamCommand.new(),
		RecallTeamCommand.new(),
		SignalTeamCommand.new(),
		ChargeAtMaximumCommand.new(),
	]


## Every registered type has a sample, and each sample rebuilds to an equal command.
func test_from_dict_rebuilds_every_registered_type() -> void:
	var sampled: Array[StringName] = []
	for command: Command in _samples():
		if not sampled.has(command.get_type()):
			sampled.append(command.get_type())
		var result := CommandFactory.from_dict(command.to_dict())
		assert_bool(result.is_ok).is_true()
		var rebuilt: Command = result.value
		assert_that(rebuilt.get_script()).is_equal(command.get_script())
		assert_dict(rebuilt.to_dict()).is_equal(command.to_dict())
	assert_array(CommandFactory.registered_types()).contains_exactly_in_any_order(sampled)


## Commands still rebuild equal after a JSON round trip, which turns ints into floats.
func test_from_dict_rebuilds_after_json_round_trip() -> void:
	for command: Command in _samples():
		var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
		var result := CommandFactory.from_dict(data)
		assert_bool(result.is_ok).is_true()
		var rebuilt: Command = result.value
		assert_dict(rebuilt.to_dict()).is_equal(command.to_dict())
		assert_int(typeof(rebuilt.get("value"))).is_equal(typeof(command.get("value")))


## An unknown type fails with &"unknown_command".
func test_from_dict_unknown_type_fails() -> void:
	var result := CommandFactory.from_dict({"type": "summon_jaffa"})
	assert_bool(result.is_ok).is_false()
	assert_that(result.error_code).is_equal(&"unknown_command")
	assert_that(result.value).is_null()


## Data without a string type fails with &"malformed_command".
func test_from_dict_missing_or_bad_type_fails() -> void:
	for data: Dictionary in [{}, {"type": 3}, {"type": null}]:
		var result := CommandFactory.from_dict(data)
		assert_bool(result.is_ok).is_false()
		assert_that(result.error_code).is_equal(&"malformed_command")


## set_flag data without a string key or without a value fails with &"malformed_command".
func test_from_dict_malformed_set_flag_fails() -> void:
	var bad_data: Array[Dictionary] = [
		{"type": "set_flag", "value": true},
		{"type": "set_flag", "key": 5, "value": true},
		{"type": "set_flag", "key": "a"},
	]
	for data: Dictionary in bad_data:
		var result := CommandFactory.from_dict(data)
		assert_bool(result.is_ok).is_false()
		assert_that(result.error_code).is_equal(&"malformed_command")


## A non-integral float survives the rebuild so validate() can reject it.
func test_from_dict_keeps_fractional_float_for_validation() -> void:
	var result := CommandFactory.from_dict({"type": "set_flag", "key": "a", "value": 1.5})
	assert_bool(result.is_ok).is_true()
	var command: Command = result.value
	assert_that(command.validate(GameState.new_game(1)).error_code).is_equal(&"invalid_value")


## A whole-number float outside the int64 range stays a float, so validate() rejects it
## instead of it wrapping to a bogus int.
func test_from_dict_keeps_out_of_range_float_for_validation() -> void:
	for value: float in [1e30, -1e30, 9223372036854775808.0]:
		var data: Dictionary = {"type": "set_flag", "key": "a", "value": value}
		var result := CommandFactory.from_dict(data)
		assert_bool(result.is_ok).is_true()
		var command: Command = result.value
		assert_int(typeof(command.get("value"))).is_equal(TYPE_FLOAT)
		var check := command.validate(GameState.new_game(1))
		assert_that(check.error_code).is_equal(&"invalid_value")


## Whole-number floats inside the int64 range, including its lower limit, become ints.
func test_from_dict_converts_in_range_whole_floats_to_int() -> void:
	for value: float in [0.0, -3.0, 1e15, -9223372036854775808.0]:
		var data: Dictionary = {"type": "set_flag", "key": "a", "value": value}
		var result := CommandFactory.from_dict(data)
		var command: Command = result.value
		assert_that(command.get("value")).is_equal(int(value))


## The built-in types are registered without any setup.
func test_defaults_are_registered_lazily() -> void:
	(
		assert_array(CommandFactory.registered_types())
		. contains_exactly(
			[
				&"accept_request",
				&"answer_call",
				&"answer_incoming",
				&"assign_staff",
				&"build_door",
				&"cancel_build",
				&"cancel_research",
				&"charge_at_maximum",
				&"choose_option",
				&"close_wormhole",
				&"debug_cheat",
				&"debug_story",
				&"decline_request",
				&"deliver_document",
				&"demolish_room",
				&"dial",
				&"dig_level",
				&"dismiss",
				&"end_conversation",
				&"extend_pole_camera",
				&"hail",
				&"hire",
				&"house_artefact",
				&"ignore_incoming",
				&"install",
				&"launch_canister",
				&"launch_moth",
				&"mark_document_read",
				&"moth_scan",
				&"note_address",
				&"operate_gate",
				&"order_squad",
				&"override_slow",
				&"paint_corridor",
				&"place_room",
				&"plan_expedition",
				&"queue_research",
				&"raise_world_fact",
				&"raise_world_status",
				&"read_console",
				&"recall_team",
				&"remove_door",
				&"remove_installation",
				&"repair_room",
				&"retrieve_artefact",
				&"send_team",
				&"set_charge_rate",
				&"set_door",
				&"set_flag",
				&"signal_team",
				&"stand_by",
				&"start_research",
				&"switch_room",
				&"unassign_staff",
				&"unhouse_artefact",
				&"unqueue_research",
			]
		)
	)


## register_type() adds a type that from_dict() can then rebuild.
func test_register_type_adds_a_type() -> void:
	CommandFactory.register_type(&"ping", PingCommand)
	var result := CommandFactory.from_dict({"type": "ping"})
	assert_bool(result.is_ok).is_true()
	var rebuilt: Command = result.value
	assert_that(rebuilt.get_type()).is_equal(&"ping")
	(
		assert_array(CommandFactory.registered_types())
		. contains_exactly(
			[
				&"accept_request",
				&"answer_call",
				&"answer_incoming",
				&"assign_staff",
				&"build_door",
				&"cancel_build",
				&"cancel_research",
				&"charge_at_maximum",
				&"choose_option",
				&"close_wormhole",
				&"debug_cheat",
				&"debug_story",
				&"decline_request",
				&"deliver_document",
				&"demolish_room",
				&"dial",
				&"dig_level",
				&"dismiss",
				&"end_conversation",
				&"extend_pole_camera",
				&"hail",
				&"hire",
				&"house_artefact",
				&"ignore_incoming",
				&"install",
				&"launch_canister",
				&"launch_moth",
				&"mark_document_read",
				&"moth_scan",
				&"note_address",
				&"operate_gate",
				&"order_squad",
				&"override_slow",
				&"paint_corridor",
				&"ping",
				&"place_room",
				&"plan_expedition",
				&"queue_research",
				&"raise_world_fact",
				&"raise_world_status",
				&"read_console",
				&"recall_team",
				&"remove_door",
				&"remove_installation",
				&"repair_room",
				&"retrieve_artefact",
				&"send_team",
				&"set_charge_rate",
				&"set_door",
				&"set_flag",
				&"signal_team",
				&"stand_by",
				&"start_research",
				&"switch_room",
				&"unassign_staff",
				&"unhouse_artefact",
				&"unqueue_research",
			]
		)
	)


## reset() removes test registrations and the defaults come back on next use.
func test_reset_removes_registrations_and_restores_defaults() -> void:
	CommandFactory.register_type(&"ping", PingCommand)
	CommandFactory.reset()
	assert_that(CommandFactory.from_dict({"type": "ping"}).error_code).is_equal(&"unknown_command")
	(
		assert_bool(CommandFactory.from_dict({"type": "set_flag", "key": "a", "value": 1}).is_ok)
		. is_true()
	)
	(
		assert_array(CommandFactory.registered_types())
		. contains_exactly(
			[
				&"accept_request",
				&"answer_call",
				&"answer_incoming",
				&"assign_staff",
				&"build_door",
				&"cancel_build",
				&"cancel_research",
				&"charge_at_maximum",
				&"choose_option",
				&"close_wormhole",
				&"debug_cheat",
				&"debug_story",
				&"decline_request",
				&"deliver_document",
				&"demolish_room",
				&"dial",
				&"dig_level",
				&"dismiss",
				&"end_conversation",
				&"extend_pole_camera",
				&"hail",
				&"hire",
				&"house_artefact",
				&"ignore_incoming",
				&"install",
				&"launch_canister",
				&"launch_moth",
				&"mark_document_read",
				&"moth_scan",
				&"note_address",
				&"operate_gate",
				&"order_squad",
				&"override_slow",
				&"paint_corridor",
				&"place_room",
				&"plan_expedition",
				&"queue_research",
				&"raise_world_fact",
				&"raise_world_status",
				&"read_console",
				&"recall_team",
				&"remove_door",
				&"remove_installation",
				&"repair_room",
				&"retrieve_artefact",
				&"send_team",
				&"set_charge_rate",
				&"set_door",
				&"set_flag",
				&"signal_team",
				&"stand_by",
				&"start_research",
				&"switch_room",
				&"unassign_staff",
				&"unhouse_artefact",
				&"unqueue_research",
			]
		)
	)
