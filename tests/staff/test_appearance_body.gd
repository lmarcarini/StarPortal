extends GdUnitTestSuite
## Tests of the build and height of the appearance record (card M8-05,
## docs/content/portraits.md "Full body"): rolled from the seed, weighted by sex, saved and
## validated.

const ROLLS: int = 1000


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## [param sex] records' counts by "build" and by "height" (as "h<value>") over ROLLS rolls.
func _counts(sex: String) -> Dictionary[String, int]:
	var rng: RandomNumberGenerator = _rng(580)
	var counts: Dictionary[String, int] = {}
	for _i: int in ROLLS:
		var record: Dictionary = AppearanceRules.roll(rng, "military", sex)
		var build: String = record["build"]
		var height_key: String = "h%d" % record["height"]
		counts[build] = counts.get(build, 0) + 1
		counts[height_key] = counts.get(height_key, 0) + 1
	return counts


func _mean_height(counts: Dictionary[String, int]) -> float:
	var total: int = 0
	for h: int in range(AppearanceRules.HEIGHT_MIN, AppearanceRules.HEIGHT_MAX + 1):
		total += h * counts.get("h%d" % h, 0)
	return total / float(ROLLS)


func test_rolls_have_build_and_height_from_the_seed() -> void:
	var a: Dictionary = AppearanceRules.roll(_rng(11), "science")
	var b: Dictionary = AppearanceRules.roll(_rng(11), "science")
	assert_str(a["build"]).is_equal(b["build"])
	assert_int(a["height"]).is_equal(b["height"])
	assert_bool(a["build"] in AppearanceRules.BUILDS).is_true()


func test_every_build_and_height_appears() -> void:
	var rng: RandomNumberGenerator = _rng(7)
	var seen: Dictionary = {}
	for _i: int in ROLLS:
		var record: Dictionary = AppearanceRules.roll(rng, "office")
		seen[record["build"]] = true
		seen["h%d" % record["height"]] = true
	for build: String in AppearanceRules.BUILDS:
		assert_bool(seen.has(build)).override_failure_message(build).is_true()
	for h: int in range(AppearanceRules.HEIGHT_MIN, AppearanceRules.HEIGHT_MAX + 1):
		assert_bool(seen.has("h%d" % h)).override_failure_message(str(h)).is_true()


## Women 3/4/1 (slim 37.5 %, broad 12.5 %), men 2/4/2 (25 % each); allow ±6 points.
func test_build_weights_hold() -> void:
	var women: Dictionary[String, int] = _counts("female")
	var men: Dictionary[String, int] = _counts("male")
	assert_int(women["slim"]).is_between(315, 435)
	assert_int(women["broad"]).is_between(65, 185)
	assert_int(men["slim"]).is_between(190, 310)
	assert_int(men["broad"]).is_between(190, 310)
	assert_int(men["average"]).is_between(440, 560)


## Men centre on 0 (0 the commonest height); women are about 2 px shorter on average.
func test_height_weights_hold() -> void:
	var women: Dictionary[String, int] = _counts("female")
	var men: Dictionary[String, int] = _counts("male")
	for h: int in [-4, -3, -2, -1, 1, 2, 3]:
		assert_int(men.get("h%d" % h, 0)).is_less(men["h0"])
	var gap: float = _mean_height(men) - _mean_height(women)
	assert_float(gap).is_between(1.4, 2.4)


func test_bad_build_or_height_is_rejected() -> void:
	var good: Dictionary = AppearanceRules.roll(_rng(5), "medicine")
	assert_array(AppearanceRules.validate(good)).is_empty()
	for change: Array in [
		["build", "huge"],
		["build", 1],
		["height", 4],
		["height", -5],
		["height", 1.5],
		["height", "0"]
	]:
		var bad: Dictionary = good.duplicate()
		bad[change[0]] = change[1]
		assert_array(AppearanceRules.validate(bad)).is_not_empty()
	for key: String in ["build", "height"]:
		var missing: Dictionary = good.duplicate()
		missing.erase(key)
		assert_array(AppearanceRules.validate(missing)).is_not_empty()


func test_build_and_height_survive_a_save() -> void:
	var person := PersonState.new()
	person.id = &"person_1"
	person.name = "Sgt Owen Hale"
	person.role = StartingStaff.SOLDIER
	person.appearance = AppearanceRules.roll(_rng(3), "military")
	person.appearance["build"] = "broad"
	person.appearance["height"] = -4
	var data: Dictionary = JSON.parse_string(JSON.stringify(person.to_dict()))
	assert_array(PersonState.validate_dict(data)).is_empty()
	var loaded: Dictionary = PersonState.from_dict(data).appearance
	assert_str(loaded["build"]).is_equal("broad")
	assert_int(loaded["height"]).is_equal(-4)
	assert_bool(loaded["height"] is int).is_true()
