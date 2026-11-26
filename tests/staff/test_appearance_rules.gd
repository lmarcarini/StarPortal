extends GdUnitTestSuite
## Tests of AppearanceRules (card M8-01, docs/content/portraits.md "The appearance record").

const ROLLS: int = 2000
const NAMES_PATH: String = "res://data/staff/staff_names.tres"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _rolls(field: String) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = _rng(42)
	var out: Array[Dictionary] = []
	for _i: int in ROLLS:
		out.append(AppearanceRules.roll(rng, field))
	return out


func test_same_seed_same_record() -> void:
	for seed_value: int in [1, 7, 99, 123456]:
		var a: Dictionary = AppearanceRules.roll(_rng(seed_value), "science")
		var b: Dictionary = AppearanceRules.roll(_rng(seed_value), "science")
		assert_dict(a).is_equal(b)
	assert_dict(AppearanceRules.roll_seeded("Dr Ana Ferreira", "science")).is_equal(
		AppearanceRules.roll_seeded("Dr Ana Ferreira", "science")
	)


func test_every_roll_is_valid() -> void:
	for field: String in AppearanceRules.VARIANTS:
		for record: Dictionary in _rolls(field):
			assert_array(AppearanceRules.validate(record)).is_empty()
			assert_str(record["field"]).is_equal(field)


func test_every_option_reachable() -> void:
	var seen: Dictionary = {}
	for field: String in AppearanceRules.VARIANTS:
		for record: Dictionary in _rolls(field):
			for key: String in record:
				seen["%s=%s" % [key, record[key]]] = true
	var lists: Dictionary = {
		"sex": AppearanceRules.SEXES,
		"age": AppearanceRules.AGES,
		"head": AppearanceRules.HEADS,
		"jaw": AppearanceRules.JAWS,
		"eyes": AppearanceRules.EYES,
		"brows": AppearanceRules.BROWS,
		"nose": AppearanceRules.NOSES,
		"mouth": AppearanceRules.MOUTHS,
		"facial_hair": AppearanceRules.FACIAL_HAIR,
		"hair": AppearanceRules.HAIR,
		"accessory": AppearanceRules.ACCESSORIES,
	}
	for key: String in lists:
		for option: String in lists[key]:
			(
				assert_bool(seen.has("%s=%s" % [key, option]))
				. override_failure_message("never rolled %s=%s" % [key, option])
				. is_true()
			)
	for index: int in AppearanceRules.SKIN_TONES:
		assert_bool(seen.has("skin=%d" % index)).is_true()
	for index: int in AppearanceRules.HAIR_COLOURS:
		assert_bool(seen.has("hair_colour=%d" % index)).is_true()
	for index: int in AppearanceRules.EYE_COLOURS:
		assert_bool(seen.has("eye_colour=%d" % index)).is_true()
	for width: int in [-1, 0, 1]:
		assert_bool(seen.has("face_width=%d" % width)).is_true()
	for field: String in AppearanceRules.VARIANTS:
		for variant: String in AppearanceRules.VARIANTS[field]:
			assert_bool(seen.has("variant=%s" % variant)).is_true()


func test_constraints() -> void:
	var older: int = 0
	var older_grey: int = 0
	for record: Dictionary in _rolls("military"):
		if record["age"] == "young":
			assert_str(record["facial_hair"]).is_not_equal("beard")
		if record["sex"] == "female":
			assert_str(record["facial_hair"]).is_equal("none")
		if record["age"] == "older":
			older += 1
			if record["hair_colour"] >= AppearanceRules.NATURAL_HAIR_COLOURS:
				older_grey += 1
		else:
			assert_int(record["hair_colour"]).is_less(AppearanceRules.NATURAL_HAIR_COLOURS)
	assert_float(float(older_grey) / older).is_greater(0.5)


func test_glasses_likelier_in_lab_coat_or_tie() -> void:
	var with_coat: Array[int] = [0, 0]
	var without: Array[int] = [0, 0]
	for record: Dictionary in _rolls("science"):
		var bucket: Array[int] = (
			with_coat if record["variant"] in AppearanceRules.GLASSES_VARIANTS else without
		)
		bucket[0] += 1
		if record["accessory"] == "glasses":
			bucket[1] += 1
	assert_float(float(with_coat[1]) / with_coat[0]).is_greater(
		float(without[1]) / without[0] + 0.2
	)


func test_field_for_role() -> void:
	assert_str(AppearanceRules.field_for_role(StartingStaff.SCIENTIST)).is_equal("science")
	assert_str(AppearanceRules.field_for_role(StartingStaff.SOLDIER)).is_equal("military")
	assert_str(AppearanceRules.field_for_role(&"role_unknown")).is_equal("office")


func test_validate_rejects_bad_records() -> void:
	var good: Dictionary = AppearanceRules.roll(_rng(5), "medicine")
	assert_array(AppearanceRules.validate({})).is_not_empty()
	for change: Array in [
		["sex", "other"], ["skin", 6], ["face_width", 2], ["variant", "suit"], ["hair", 3]
	]:
		var bad: Dictionary = good.duplicate()
		bad[change[0]] = change[1]
		assert_array(AppearanceRules.validate(bad)).is_not_empty()


func test_saved_record_survives_json() -> void:
	var person := PersonState.new()
	person.id = &"person_1"
	person.name = "Dr Ana Ferreira"
	person.role = StartingStaff.SCIENTIST
	person.appearance = AppearanceRules.roll(_rng(3), "science")
	var data: Dictionary = JSON.parse_string(JSON.stringify(person.to_dict()))
	assert_array(PersonState.validate_dict(data)).is_empty()
	assert_dict(PersonState.from_dict(data).appearance).is_equal(person.appearance)


func test_save_without_record_is_rejected() -> void:
	var person := PersonState.new()
	person.id = &"person_1"
	person.name = "Dr Ana Ferreira"
	person.role = StartingStaff.SCIENTIST
	var data: Dictionary = person.to_dict()
	data.erase("appearance")
	assert_array(PersonState.validate_dict(data)).contains(["missing 'appearance'"])


func test_starting_crew_and_hires_have_records() -> void:
	var staff: StaffState = StartingStaff.build(BaseState.new(), BalanceConfig.new())
	for person: PersonState in staff.people:
		assert_array(AppearanceRules.validate(person.appearance)).is_empty()
	for candidate: CandidateState in RecruitmentRules.first_list(BalanceConfig.new()):
		assert_array(AppearanceRules.validate(candidate.appearance)).is_empty()


func test_drawn_names_fit_the_sex() -> void:
	var names: StaffNameListDef = load(NAMES_PATH)
	var balance := BalanceConfig.new()
	var rng: RandomNumberGenerator = _rng(11)
	var seen_unisex: Dictionary = {}
	for role_path: String in [
		"res://data/staff/role_scientist.tres", "res://data/staff/role_analyst.tres"
	]:
		var role: RoleDef = load(role_path)
		for _i: int in ROLLS:
			var candidate: CandidateState = RecruitmentRules.draw_candidate(
				rng, balance, role, names
			)
			var parts: PackedStringArray = candidate.name.split(" ")
			var given: String = parts[parts.size() - 2]
			var sex: String = candidate.appearance["sex"]
			assert_array(names.given_names_for(sex)).contains([given])
			if given in names.unisex_names:
				seen_unisex["%s=%s" % [given, sex]] = true
	assert_bool(seen_unisex.has("Alex=female") and seen_unisex.has("Alex=male")).is_true()


func test_fixed_names_have_their_sex() -> void:
	var staff: StaffState = StartingStaff.build(BaseState.new(), BalanceConfig.new())
	for person: PersonState in staff.people:
		assert_str(person.appearance["sex"]).is_equal(
			"male" if person.name in ["Dr Tom Okafor", "Cpl Raul Mendes"] else "female"
		)
	for candidate: CandidateState in RecruitmentRules.first_list(BalanceConfig.new()):
		assert_str(candidate.appearance["sex"]).is_equal(
			"male" if candidate.name in ["Dr Kenji Arai", "Sgt Dan Kowalski"] else "female"
		)


func test_name_lists_are_valid() -> void:
	var names: StaffNameListDef = load(NAMES_PATH)
	assert_array(names.get_content_errors({})).is_empty()
	var bad := StaffNameListDef.new()
	bad.female_names = ["Alex"]
	bad.male_names = ["Leo"]
	bad.unisex_names = ["Alex"]
	bad.surnames = ["Berg"]
	assert_array(bad.get_content_errors({})).is_not_empty()
