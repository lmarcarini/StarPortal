## Tests for IntelState: lookups, add_clue(), the saved shape, JSON round trips and
## validate_dict() on duplicate clue ids, notes for unknown clues, links to unknown clues or
## to the clue itself, counters and scheduled dossiers.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#player-tools, technical-architecture.md#data-model
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")


func _intel_data() -> Dictionary:
	return Fixture.state().intel.to_dict()


func _assert_has_error(data: Dictionary, expected: String) -> void:
	var errors := IntelState.validate_dict(data)
	var found := errors.any(func(error: String) -> bool: return error.contains(expected))
	assert_bool(found).override_failure_message("%s: %s" % [expected, str(errors)]).is_true()


## A new IntelState is empty with both counters at 1, and valid.
func test_defaults() -> void:
	var intel := IntelState.new()
	assert_array(intel.clues).is_empty()
	assert_dict(intel.notes).is_empty()
	assert_int(intel.next_clue_number).is_equal(1)
	assert_int(intel.next_dossier_number).is_equal(1)
	assert_dict(intel.scheduled_dossiers).is_empty()
	assert_array(IntelState.validate_dict(intel.to_dict())).is_empty()


## get_clue() finds clues by id and returns null for an unknown one; add_clue() appends in
## arrival order.
func test_get_clue_and_add_clue() -> void:
	var intel := Fixture.state().intel
	assert_str(intel.get_clue(Fixture.SKY_CHART_ID).id).is_equal(Fixture.SKY_CHART_ID)
	assert_object(intel.get_clue(&"clue_9999")).is_null()
	intel.add_clue(Fixture.fragment(&"clue_0003"))
	assert_str(intel.clues[2].id).is_equal(&"clue_0003")
	assert_int(intel.next_clue_number).is_equal(3)


## add_clue() asserts on a duplicate id.
func test_add_clue_asserts_on_duplicate() -> void:
	var intel := Fixture.state().intel
	await (
		assert_error(func() -> void: intel.add_clue(Fixture.fragment()))
		. is_runtime_error("Assertion failed: IntelState.add_clue(): 'clue_0001' already exists")
	)


## note_for() returns the stored note, or a fresh default for a clue without one.
func test_note_for() -> void:
	var intel := Fixture.state().intel
	assert_bool(intel.note_for(Fixture.FRAGMENT_ID).is_suspect).is_true()
	var fresh := intel.note_for(&"clue_9999")
	assert_bool(fresh.is_default()).is_true()
	fresh.is_suspect = true
	assert_bool(intel.note_for(&"clue_9999").is_default()).is_true()
	assert_bool(intel.notes.has(&"clue_9999")).is_false()


## The saved shape and a JSON round trip.
func test_json_round_trip() -> void:
	var data := _intel_data()
	assert_array(data.keys()).contains_exactly_in_any_order(
		["clues", "notes", "next_clue_number", "next_dossier_number", "scheduled_dossiers"]
	)
	assert_dict(data["scheduled_dossiers"]).is_equal({"world_abydos": 5000})
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(IntelState.validate_dict(parsed)).is_empty()
	var restored := IntelState.from_dict(parsed)
	assert_dict(restored.to_dict()).is_equal(data)
	assert_int(typeof(restored.scheduled_dossiers[&"world_abydos"])).is_equal(TYPE_INT)
	assert_int(typeof(restored.next_clue_number)).is_equal(TYPE_INT)


## Duplicate clue ids and invalid clues are rejected, with the clue's index.
func test_rejects_duplicate_and_invalid_clues() -> void:
	var data := _intel_data()
	data["clues"][1]["id"] = "clue_0001"
	_assert_has_error(data, "clue 1 repeats id 'clue_0001'")
	data = _intel_data()
	data["clues"][1]["grade"] = 5
	_assert_has_error(data, "clue 1: 'grade'")
	data["clues"] = [1]
	_assert_has_error(data, "clue 0 is not an object")
	data["clues"] = {}
	_assert_has_error(data, "'clues' is not an array")


## Notes for unknown clues, links to unknown clues or to the clue itself, and invalid notes
## are rejected.
func test_rejects_bad_notes() -> void:
	var data := _intel_data()
	data["notes"]["clue_9999"] = ClueNote.new().to_dict()
	_assert_has_error(data, "note for unknown clue 'clue_9999'")
	data = _intel_data()
	data["notes"]["clue_0001"]["links"] = ["clue_0002", "clue_9999"]
	_assert_has_error(data, "note 'clue_0001' links to unknown clue 'clue_9999'")
	data["notes"]["clue_0001"]["links"] = ["clue_0001"]
	_assert_has_error(data, "note 'clue_0001' links to itself")
	data = _intel_data()
	data["notes"]["clue_0002"]["tags"] = ["x".repeat(33)]
	_assert_has_error(data, "note 'clue_0002': tag 0")
	data["notes"]["clue_0002"] = 3
	_assert_has_error(data, "note 'clue_0002' is not an object")
	data["notes"] = []
	_assert_has_error(data, "'notes' is not an object")


## Counters are whole numbers from 1; dossier ticks whole numbers from 0, keyed by world id.
func test_rejects_bad_counters_and_schedule() -> void:
	for key: String in ["next_clue_number", "next_dossier_number"]:
		for bad: Variant in [0, -1, 1.5, "2", null]:
			var data := _intel_data()
			data[key] = bad
			_assert_has_error(data, "'%s'" % key)
	for bad: Variant in [-1, 0.5, "5", null]:
		var data := _intel_data()
		data["scheduled_dossiers"]["world_chulak"] = bad
		_assert_has_error(data, "dossier for 'world_chulak'")
	var data := _intel_data()
	data["scheduled_dossiers"][""] = 5
	_assert_has_error(data, "empty world id")
	data["scheduled_dossiers"] = []
	_assert_has_error(data, "'scheduled_dossiers' is not an object")
