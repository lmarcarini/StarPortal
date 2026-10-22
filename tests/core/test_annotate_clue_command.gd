## Tests for AnnotateClueCommand: validation against the state's clues, apply() replacing
## the whole note and posting clue_note_changed once, and rebuilding through CommandFactory.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")


func after_test() -> void:
	CommandFactory.reset()


func _note(links: Array[StringName] = [], tags: Array[String] = ["Abydos"]) -> ClueNote:
	return Fixture.note(links, tags)


func _assert_fails(command: AnnotateClueCommand, code: StringName) -> void:
	var state := Fixture.state()
	var before := state.to_dict()
	var result := command.validate(state)
	assert_bool(result.is_ok).override_failure_message(str(command.to_dict())).is_false()
	assert_str(result.error_code).override_failure_message(result.detail).is_equal(code)
	assert_dict(state.to_dict()).is_equal(before)


## A valid command replaces the whole note and posts clue_note_changed(clue_id) once.
func test_replaces_whole_note_and_posts_once() -> void:
	var state := Fixture.state()
	var replacement := ClueNote.new()
	replacement.tags.append("new")
	replacement.board_position = Vector2i(4000, 0)
	var command := AnnotateClueCommand.create(Fixture.FRAGMENT_ID, replacement)
	assert_bool(command.validate(state).is_ok).is_true()
	command.apply(state)
	assert_dict(state.intel.notes[Fixture.FRAGMENT_ID].to_dict()).is_equal(replacement.to_dict())
	assert_bool(state.intel.note_for(Fixture.FRAGMENT_ID).is_suspect).is_false()
	assert_array(state.intel.note_for(Fixture.FRAGMENT_ID).links).is_empty()
	var events := state.events.drain()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].name).is_equal(&"clue_note_changed")
	assert_array(events[0].args).is_equal([Fixture.FRAGMENT_ID])


## A note on a clue without one is added; a default note removes the stored one.
func test_adds_and_removes_notes() -> void:
	var state := GameState.new_game(1)
	state.intel.add_clue(Fixture.fragment())
	state.intel.add_clue(Fixture.sky_chart())
	var links: Array[StringName] = [Fixture.SKY_CHART_ID]
	AnnotateClueCommand.create(Fixture.FRAGMENT_ID, _note(links)).apply(state)
	assert_array(state.intel.notes.keys()).is_equal([Fixture.FRAGMENT_ID])
	var cleared := AnnotateClueCommand.create(Fixture.FRAGMENT_ID, ClueNote.new())
	assert_bool(cleared.validate(state).is_ok).is_true()
	cleared.apply(state)
	assert_dict(state.intel.notes).is_empty()
	assert_int(state.events.size()).is_equal(2)


## The state keeps a copy of the note: changing the caller's note changes nothing.
func test_state_keeps_a_copy() -> void:
	var state := Fixture.state()
	var note := _note()
	var command := AnnotateClueCommand.create(Fixture.SKY_CHART_ID, note)
	command.apply(state)
	note.tags.append("later")
	command.note.tags.append("later")
	assert_array(state.intel.notes[Fixture.SKY_CHART_ID].tags).is_equal(["Abydos"])


## An unknown clue fails with &"unknown_clue".
func test_rejects_unknown_clue() -> void:
	_assert_fails(AnnotateClueCommand.create(&"clue_9999", _note()), &"unknown_clue")
	_assert_fails(AnnotateClueCommand.create(&"", _note()), &"unknown_clue")


## Every invalid note fails with &"invalid_note": too many, too long, empty or control
## character tags, repeated links, positions off the board, or no note.
func test_rejects_invalid_notes() -> void:
	var too_many: Array[String] = []
	for index: int in ClueNote.MAX_TAGS + 1:
		too_many.append("t%d" % index)
	var cases: Array[ClueNote] = [
		_note([], too_many),
		_note([], ["x".repeat(ClueNote.MAX_TAG_LENGTH + 1)] as Array[String]),
		_note([], [""] as Array[String]),
		_note([], ["bad\ntag"] as Array[String]),
		_note([Fixture.SKY_CHART_ID, Fixture.SKY_CHART_ID] as Array[StringName]),
	]
	for position: Vector2i in [Vector2i(-1, 0), Vector2i(0, 4001), Vector2i(4001, 4001)]:
		var off_board := _note()
		off_board.board_position = position
		cases.append(off_board)
	for note: ClueNote in cases:
		_assert_fails(AnnotateClueCommand.create(Fixture.FRAGMENT_ID, note), &"invalid_note")
	_assert_fails(AnnotateClueCommand.create(Fixture.FRAGMENT_ID, null), &"invalid_note")


## Links to unknown clues or to the clue itself fail with &"invalid_link".
func test_rejects_bad_links() -> void:
	for links: Array[StringName] in [
		[&"clue_9999"] as Array[StringName],
		[Fixture.SKY_CHART_ID, &"clue_9999"] as Array[StringName],
		[Fixture.FRAGMENT_ID] as Array[StringName],
	]:
		_assert_fails(
			AnnotateClueCommand.create(Fixture.FRAGMENT_ID, _note(links)), &"invalid_link"
		)


## The command rebuilds identically through CommandFactory, also after JSON.
func test_rebuilds_through_factory() -> void:
	var links: Array[StringName] = [Fixture.SKY_CHART_ID]
	var command := AnnotateClueCommand.create(Fixture.FRAGMENT_ID, _note(links))
	var data := command.to_dict()
	assert_str(data["type"]).is_equal("annotate_clue")
	assert_str(data["clue_id"]).is_equal("clue_0001")
	for source: Dictionary in [data, JSON.parse_string(JSON.stringify(data))]:
		var result := CommandFactory.from_dict(source)
		assert_bool(result.is_ok).override_failure_message(result.detail).is_true()
		var rebuilt: Command = result.value
		assert_object(rebuilt).is_instanceof(AnnotateClueCommand)
		assert_dict(rebuilt.to_dict()).is_equal(data)
		var rebuilt_command: AnnotateClueCommand = rebuilt
		assert_that(rebuilt_command.note.board_position).is_equal(Vector2i(120, 3400))
		assert_bool(rebuilt.validate(Fixture.state()).is_ok).is_true()


## from_dict() fails with &"malformed_command" on a missing clue id or note, or a note that
## fails ClueNote.validate_dict().
func test_from_dict_rejects_malformed_data() -> void:
	var good := AnnotateClueCommand.create(Fixture.FRAGMENT_ID, _note()).to_dict()
	var cases: Array[Array] = [
		["clue_id", null],
		["clue_id", 7],
		["note", null],
		["note", []],
		["note", {"is_suspect": true}],
		["note", {"is_suspect": 1, "tags": [], "links": [], "board_position": [0, 0]}],
		["note", {"is_suspect": true, "tags": [3], "links": [], "board_position": [0, 0]}],
		["note", {"is_suspect": true, "tags": [], "links": [], "board_position": [0.5, 0]}],
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
