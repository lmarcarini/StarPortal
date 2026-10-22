## Tests for SetWorkbenchCommand: validation of the origin and constraints, apply() replacing
## the draft and posting workbench_changed once, and rebuilding through CommandFactory.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")


func after_test() -> void:
	CommandFactory.reset()


func _command(origin: int = 12) -> SetWorkbenchCommand:
	return SetWorkbenchCommand.create(origin, Fixture.five_constraints())


func _assert_fails(command: SetWorkbenchCommand, code: StringName) -> void:
	var result := command.validate(GameState.new_game(1))
	assert_bool(result.is_ok).override_failure_message(str(command.to_dict())).is_false()
	assert_str(result.error_code).is_equal(code)


## A valid command applies: origin and constraints are replaced and workbench_changed is
## posted once with no arguments.
func test_applies_and_posts_once() -> void:
	var state := Fixture.state()
	var command := _command()
	assert_bool(command.validate(state).is_ok).is_true()
	command.apply(state)
	assert_int(state.workbench.origin_glyph).is_equal(12)
	assert_dict(state.workbench.to_dict()).is_equal(
		{"origin_glyph": 12, "constraints": command.to_dict()["constraints"]}
	)
	var events := state.events.drain()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].name).is_equal(&"workbench_changed")
	assert_array(events[0].args).is_empty()


## An empty draft at the home origin is valid and clears the old draft.
func test_clears_the_draft() -> void:
	var state := Fixture.state()
	var empty: Array[AddressConstraint] = []
	var command := SetWorkbenchCommand.create(-1, empty)
	assert_bool(command.validate(state).is_ok).is_true()
	command.apply(state)
	assert_dict(state.workbench.to_dict()).is_equal({"origin_glyph": -1, "constraints": []})


## The state keeps copies: changing the command's constraints afterwards changes nothing.
func test_state_keeps_copies() -> void:
	var state := GameState.new_game(1)
	var command := _command()
	command.apply(state)
	command.constraints[0].seal = 7
	command.constraints.clear()
	assert_array(state.workbench.constraints).has_size(5)
	assert_int(state.workbench.constraints[0].seal).is_equal(2)


## Origins outside -1..35 fail with &"invalid_origin".
func test_rejects_bad_origin() -> void:
	for origin: int in [-2, 36, 1000]:
		_assert_fails(_command(origin), &"invalid_origin")
	for origin: int in [-1, 0, 35]:
		assert_bool(_command(origin).validate(GameState.new_game(1)).is_ok).is_true()


## More than 64 constraints fail with &"too_many_constraints"; 64 pass.
func test_rejects_too_many_constraints() -> void:
	var many: Array[AddressConstraint] = []
	for index: int in WorkbenchState.MAX_CONSTRAINTS:
		many.append(AddressConstraint.excluded(index % GateAddress.GLYPH_COUNT))
	(
		assert_bool(SetWorkbenchCommand.create(-1, many).validate(GameState.new_game(1)).is_ok)
		. is_true()
	)
	many.append(AddressConstraint.excluded(0))
	_assert_fails(SetWorkbenchCommand.create(-1, many), &"too_many_constraints")


## Null or malformed constraints fail with &"malformed_constraint".
func test_rejects_malformed_constraints() -> void:
	var bad_seal := AddressConstraint.glyph_at(9, 1)
	var bad_glyph := AddressConstraint.excluded(36)
	var short_set := AddressConstraint.exact_set([1, 2] as Array[int])
	var unknown := AddressConstraint.excluded(1)
	unknown.kind = -1 as AddressConstraint.Kind
	for bad: AddressConstraint in [bad_seal, bad_glyph, short_set, unknown, null]:
		var constraints := Fixture.five_constraints()
		constraints.append(bad)
		_assert_fails(SetWorkbenchCommand.create(3, constraints), &"malformed_constraint")


## The command rebuilds identically through CommandFactory, also after JSON.
func test_rebuilds_through_factory() -> void:
	var command := _command()
	var data := command.to_dict()
	assert_str(data["type"]).is_equal("set_workbench")
	for source: Dictionary in [data, JSON.parse_string(JSON.stringify(data))]:
		var result := CommandFactory.from_dict(source)
		assert_bool(result.is_ok).override_failure_message(result.detail).is_true()
		var rebuilt: Command = result.value
		assert_object(rebuilt).is_instanceof(SetWorkbenchCommand)
		assert_dict(rebuilt.to_dict()).is_equal(data)
		var rebuilt_command: SetWorkbenchCommand = rebuilt
		assert_int(typeof(rebuilt_command.origin_glyph)).is_equal(TYPE_INT)


## from_dict() fails with &"malformed_command" on a missing or fractional origin, a missing
## constraint list, or a constraint that fails AddressConstraint.validate_dict().
func test_from_dict_rejects_malformed_data() -> void:
	var good := _command().to_dict()
	var cases: Array[Array] = [
		["origin_glyph", null],
		["origin_glyph", 1.5],
		["origin_glyph", "3"],
		["constraints", null],
		["constraints", {}],
		["constraints", [3]],
		["constraints", [{"kind": "glyph_at", "seal": 2.5, "glyphs": [1]}]],
		["constraints", [{"kind": "excluded", "glyphs": [1.5]}]],
	]
	for case: Array in cases:
		var data := good.duplicate(true)
		data[case[0]] = case[1]
		if case[1] == null:
			data.erase(case[0])
		var result := CommandFactory.from_dict(data)
		assert_str(result.error_code).override_failure_message(str(case)).is_equal(
			&"malformed_command"
		)


## An out-of-range origin rebuilds and is then rejected by validate().
func test_out_of_range_origin_rebuilds_then_fails_validation() -> void:
	var data := _command(36).to_dict()
	var result := CommandFactory.from_dict(data)
	assert_bool(result.is_ok).is_true()
	var rebuilt: Command = result.value
	assert_str(rebuilt.validate(GameState.new_game(1)).error_code).is_equal(&"invalid_origin")
