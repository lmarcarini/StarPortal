## Tests for the Clue Solver's core: its counts match CandidateCounter, constraints files and
## command lines are read or rejected with a clear message, and nothing in the game refers to the
## tools. Bible: technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const Fixtures := preload("res://tests/gate/clue_fixture.gd")


func test_counts_after_match_the_counter_for_a_dossier() -> void:
	var galaxy: GalaxyCatalogue = Fixtures.galaxy()
	var origin: int = galaxy.home().origin_glyph
	var targets: Array[StringName] = Fixtures.targets(galaxy, 3)
	for index: int in targets.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + index
		var clues: Array[ClueRecord] = ClueGenerator.generate_dossier(
			targets[index], galaxy, rng, ClueSetParams.new()
		)
		var counts: Array[int] = ClueSolverCore.counts_after(
			ClueSolverCore.groups_of(clues), origin
		)
		assert_int(counts.size()).is_equal(clues.size() + 1)
		assert_int(counts[0]).is_equal(35 * 34 * 33 * 32 * 31 * 30 * 29)
		for step: int in clues.size():
			var prefix: Array[ClueRecord] = clues.slice(0, step + 1)
			assert_int(counts[step + 1]).is_equal(ClueGenerator.count_candidates(prefix, origin))
		assert_int(counts[counts.size() - 1]).is_equal(
			ClueGenerator.count_candidates(clues, origin)
		)


func test_counts_after_a_constraint_list() -> void:
	var groups: Array[Array] = [[AddressConstraint.glyph_at(1, 4)], [AddressConstraint.excluded(7)]]
	var counts: Array[int] = ClueSolverCore.counts_after(groups, 2)
	var all: Array[AddressConstraint] = [AddressConstraint.glyph_at(1, 4)]
	assert_int(counts[1]).is_equal(CandidateCounter.count(all, 2))
	all.append(AddressConstraint.excluded(7))
	assert_int(counts[2]).is_equal(CandidateCounter.count(all, 2))


func test_constraints_file_is_read() -> void:
	var text: String = '[{"kind":"glyph_at","seal":2,"glyphs":[14]},{"kind":"excluded","glyphs":[3]}]'
	var result: Result = ClueSolverCore.parse_constraints(text)
	assert_bool(result.is_ok).is_true()
	var constraints: Array[AddressConstraint] = []
	var parsed: Array = result.value
	constraints.assign(parsed)
	assert_int(constraints.size()).is_equal(2)
	assert_bool(constraints[0].equals(AddressConstraint.glyph_at(2, 14))).is_true()


func test_malformed_constraints_files_are_rejected_with_a_message() -> void:
	var cases: Dictionary = {
		"{oops": "not valid JSON",
		'{"kind":"excluded"}': "expected a JSON list",
		"[3]": "constraint 1 is not an object",
		'[{"kind":"nope","glyphs":[1]}]': "constraint 1: unknown kind 'nope'",
		'[{"kind":"excluded","glyphs":[1]},{"kind":"glyph_at","seal":9,"glyphs":[1]}]':
		"constraint 2: seal 9 is not from 1 to 7",
		'[{"kind":"excluded","glyphs":[40]}]': "constraint 1: glyph 1 is 40",
	}
	for text: String in cases:
		var result: Result = ClueSolverCore.parse_constraints(text)
		assert_bool(result.is_ok).override_failure_message(text).is_false()
		var expected: String = cases[text]
		assert_str(result.detail).override_failure_message(text).contains(expected)


func test_command_line_is_read_or_rejected() -> void:
	var good: Result = ClueSolverCore.parse_args(
		PackedStringArray(["--seed", "7", "--world", "R-0001", "--list", "3"])
	)
	assert_bool(good.is_ok).is_true()
	assert_dict(good.value).is_equal({"--seed": 7, "--world": "R-0001", "--list": 3})
	var bad: Array[PackedStringArray] = [
		PackedStringArray(["--seed", "7"]),
		PackedStringArray(["--seed", "x", "--world", "a"]),
		PackedStringArray(["--world"]),
		PackedStringArray(["--colour", "red"]),
		PackedStringArray(["--constraints", "a.json", "--seed", "1", "--world", "b"]),
		PackedStringArray(["--constraints", "a.json", "--origin", "40"]),
		PackedStringArray([]),
	]
	for args: PackedStringArray in bad:
		(
			assert_bool(ClueSolverCore.parse_args(args).is_ok)
			. override_failure_message(str(args))
			. is_false()
		)


func test_clue_text_is_plain() -> void:
	var clue := ClueRecord.new()
	clue.kind = ClueRecord.Kind.FRAGMENT
	clue.text_key = &"CLUE_FRAGMENT_ONE"
	clue.source_key = &"CLUE_SOURCE_X"
	clue.text_args = {"seal": 2, "glyph": 14}
	clue.constraints = [AddressConstraint.glyph_at(2, 14)]
	assert_str(ClueSolverCore.describe_clue(clue)).is_equal(
		(
			"[fragment] CLUE_FRAGMENT_ONE glyph=14 seal=2 (source CLUE_SOURCE_X, grade 0)\n"
			+ "    says: glyph 14 at seal 2"
		)
	)


## No game file names the tools folder, and a project export (when one exists) leaves it out.
func test_game_code_does_not_use_tools_and_export_excludes_them() -> void:
	for path: String in _files_under("res://src"):
		var text: String = FileAccess.get_file_as_string(path)
		(
			assert_bool(text.contains("res://tools") or text.contains("content_checks"))
			. override_failure_message(path)
			. is_false()
		)
	if not FileAccess.file_exists("res://export_presets.cfg"):
		return
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_str(presets).contains("tools/*")


func _files_under(dir: String) -> Array[String]:
	var found: Array[String] = []
	for entry: String in DirAccess.get_files_at(dir):
		if entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
			found.append(dir.path_join(entry))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_files_under(dir.path_join(sub)))
	return found
