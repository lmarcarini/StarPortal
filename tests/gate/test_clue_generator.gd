## Tests for ClueGenerator over a fixture galaxy: true constraints, candidate counts, kind mix,
## determinism, no duplicate claims, neighbour and sky chart rules, and speed.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#puzzle-tuning-rules
extends GdUnitTestSuite

const Fixtures := preload("res://tests/gate/clue_fixture.gd")
const TARGET_COUNT: int = 100
const MIN_IN_RANGE: int = 95
const MAX_AVERAGE_MS: float = 100.0

var _galaxy: GalaxyCatalogue
var _targets: Array[StringName] = []
var _params := ClueSetParams.new()
var _dossiers: Array[Array] = []


func before() -> void:
	_galaxy = Fixtures.galaxy()
	_targets = Fixtures.targets(_galaxy, TARGET_COUNT)
	var started: int = Time.get_ticks_msec()
	for index: int in _targets.size():
		_dossiers.append(_dossier(_targets[index], index))
	var average: float = float(Time.get_ticks_msec() - started) / _targets.size()
	print("ClueGenerator: average %.1f ms per dossier" % average)
	assert_float(average).is_less(MAX_AVERAGE_MS)


func _dossier(target: StringName, seed_value: int) -> Array[ClueRecord]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return ClueGenerator.generate_dossier(target, _galaxy, rng, _params)


func _origin() -> int:
	return _galaxy.home().origin_glyph


## Every constraint is true of the target's address from the home origin; clues are true and
## point at the target.
func test_every_constraint_holds_for_the_target() -> void:
	for index: int in _targets.size():
		var address: GateAddress = _galaxy.address_of(_targets[index], _origin())
		for clue: ClueRecord in _dossiers[index]:
			assert_bool(clue.is_true).is_true()
			assert_str(String(clue.target_world_id)).is_equal(String(_targets[index]))
			assert_bool(clue.constraints.is_empty()).is_false()
			for constraint: AddressConstraint in clue.constraints:
				assert_bool(constraint.is_well_formed()).is_true()
				assert_bool(constraint.is_satisfied_by(address)).is_true()


## At least 95 of 100 dossiers leave 1..20 candidates, none leaves 0, and the target is always
## among them.
func test_candidate_counts() -> void:
	var in_range: int = 0
	for index: int in _targets.size():
		var count: int = ClueGenerator.count_candidates(_dossiers[index], _origin())
		assert_int(count).is_greater_equal(1)
		if count <= _params.max_candidates:
			in_range += 1
	print("ClueGenerator: %d of %d dossiers within 1..20" % [in_range, TARGET_COUNT])
	assert_int(in_range).is_greater_equal(MIN_IN_RANGE)


## Three kinds at least, at most max_clues clues, and no clue states what another already does.
func test_kind_mix_and_no_duplicates() -> void:
	for dossier: Array in _dossiers:
		var kinds: Dictionary = {}
		var signatures: Dictionary = {}
		for clue: ClueRecord in dossier:
			kinds[clue.kind] = true
			var signature: String = _signature(clue)
			assert_bool(signatures.has(signature)).override_failure_message(signature).is_false()
			signatures[signature] = true
		assert_int(kinds.size()).is_greater_equal(_params.min_kinds)
		assert_int(dossier.size()).is_less_equal(_params.max_clues)


func _signature(clue: ClueRecord) -> String:
	var parts: Array[String] = [str(clue.kind)]
	for constraint: AddressConstraint in clue.constraints:
		parts.append("%d:%d:%s" % [constraint.kind, constraint.seal, constraint.glyphs])
	return "|".join(parts)


## The same seed gives the same dossier; another seed gives a different one.
func test_same_seed_same_dossier() -> void:
	for index: int in 10:
		var again: Array[ClueRecord] = _dossier(_targets[index], index)
		assert_array(_texts(again)).is_equal(_texts(_dossiers[index]))
	var other: Array[ClueRecord] = _dossier(_targets[0], 999)
	assert_array(_texts(other)).is_not_equal(_texts(_dossiers[0]))


func _texts(clues: Array) -> Array[String]:
	var result: Array[String] = []
	for clue: ClueRecord in clues:
		result.append(
			(
				"%s %s %s %s %s"
				% [clue.text_key, clue.source_key, clue.grade, clue.text_args, clue.image_glyphs]
			)
		)
		result.append(_signature(clue))
	return result


## A neighbour clue names a real designated world that shares exactly `count` (>= 2) leading
## seals with the target, and its address argument is that world's key; it never names the
## target.
func test_neighbour_clues() -> void:
	var seen: int = 0
	for index: int in _targets.size():
		var target_address: GateAddress = _galaxy.address_of(_targets[index], _origin())
		for clue: ClueRecord in _dossiers[index]:
			if clue.kind != ClueRecord.Kind.NEIGHBOUR:
				continue
			seen += 1
			var reference: WorldRecord = _world_by_designation(str(clue.text_args["world"]))
			assert_object(reference).is_not_null()
			assert_bool(reference.id == _targets[index]).is_false()
			var other: GateAddress = _galaxy.address_of(reference.id, _origin())
			assert_str(str(clue.text_args["address"])).is_equal(other.key())
			var count: int = type_convert(clue.text_args["count"], TYPE_INT)
			assert_int(count).is_greater_equal(2)
			assert_array(other.coordinates.slice(0, count)).is_equal(
				target_address.coordinates.slice(0, count)
			)
			assert_bool(other.coordinates[count] != target_address.coordinates[count]).is_true()
	assert_int(seen).is_greater(0)


func _world_by_designation(designation: String) -> WorldRecord:
	for world: WorldRecord in _galaxy.all_worlds():
		if world.designation == designation:
			return world
	return null


## A sky chart lists exactly the seven coordinates, never in address order.
func test_sky_charts() -> void:
	var seen: int = 0
	for index: int in _targets.size():
		var address: GateAddress = _galaxy.address_of(_targets[index], _origin())
		for clue: ClueRecord in _dossiers[index]:
			if clue.kind != ClueRecord.Kind.SKY_CHART:
				continue
			seen += 1
			var sorted: Array[int] = clue.image_glyphs.duplicate()
			sorted.sort()
			var expected: Array[int] = address.coordinates.duplicate()
			expected.sort()
			assert_array(sorted).is_equal(expected)
			assert_array(clue.image_glyphs).is_not_equal(address.coordinates)
	assert_int(seen).is_greater(0)


## No text argument carries the target's id or designation.
func test_no_target_identity_in_text_args() -> void:
	for index: int in _targets.size():
		var target: WorldRecord = _galaxy.get_world(_targets[index])
		for clue: ClueRecord in _dossiers[index]:
			for value: Variant in clue.text_args.values():
				assert_bool(str(value) == String(target.id)).is_false()
				assert_bool(str(value) == target.designation).is_false()


## An unknown target gives an empty dossier.
func test_unknown_target() -> void:
	var rng := RandomNumberGenerator.new()
	var clues: Array[ClueRecord] = ClueGenerator.generate_dossier(&"nowhere", _galaxy, rng, _params)
	assert_array(clues).is_empty()
