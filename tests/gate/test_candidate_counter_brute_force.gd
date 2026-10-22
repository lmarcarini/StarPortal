## Brute-force cross-check of CandidateCounter: seeded random constraint sets over a small
## alphabet (8 glyphs, length 4) are counted and listed by the counter and by plain enumeration
## of all 1,680 sequences, with an independent reading of the constraint table. Every kind,
## contradictions, duplicates, glyphs outside the alphabet and bad seals are covered.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#player-tools
extends GdUnitTestSuite

const SEED: int = 4646
const SETS: int = 600
const LENGTH: int = 4
const ALPHABET: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
## Glyphs drawn for constraints: the alphabet plus two outside it (like the origin).
const MAX_DRAWN_GLYPH: int = 9
## Lists up to this many are compared in full; longer ones by their first LIST_PREFIX.
const FULL_LIST_MAX: int = 120
const LIST_PREFIX: int = 25
## pos(g) of an absent glyph: no seal number, so GLYPH_AT seal 0 never matches it.
const ABSENT: int = -1

## Kinds drawn for the soft sets, which rarely contradict: order edges and per-seal rules
## mixed, the counter's hardest interplay.
const SOFT_KINDS: Array[int] = [
	AddressConstraint.Kind.NEARER_THAN,
	AddressConstraint.Kind.NEARER_THAN,
	AddressConstraint.Kind.NEARER_THAN,
	AddressConstraint.Kind.GLYPH_NOT_AT,
	AddressConstraint.Kind.GLYPH_NOT_AT,
	AddressConstraint.Kind.INCLUDED,
	AddressConstraint.Kind.EXCLUDED,
]
const SOFT_SETS: int = 300

var _rng: RandomNumberGenerator
var _soft: bool = false
var _sequences: Array[Array] = []


func before() -> void:
	_sequences.clear()
	var prefix: Array[int] = []
	_enumerate(prefix)


func before_test() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	_soft = false


## All sequences of LENGTH distinct ALPHABET glyphs, in lexicographic order.
func _enumerate(prefix: Array[int]) -> void:
	if prefix.size() == LENGTH:
		_sequences.append(prefix.duplicate())
		return
	for glyph: int in ALPHABET:
		if not prefix.has(glyph):
			prefix.append(glyph)
			_enumerate(prefix)
			prefix.pop_back()


## The table from the card, written out independently of AddressConstraint.
func _reference_fits(constraint: AddressConstraint, sequence: Array) -> bool:
	var glyphs: Array[int] = constraint.glyphs
	var expected_counts: Array[int] = [1, 1, 1, 1, -1, 2]
	if constraint.kind == AddressConstraint.Kind.EXACT_SET:
		return _same_set(sequence, glyphs)
	if glyphs.size() != expected_counts[constraint.kind]:
		return false
	return _reference_fits_glyph_rule(constraint, sequence)


func _reference_fits_glyph_rule(constraint: AddressConstraint, sequence: Array) -> bool:
	var glyphs: Array[int] = constraint.glyphs
	var position: int = _position(sequence, glyphs[0])
	match constraint.kind:
		AddressConstraint.Kind.GLYPH_AT:
			return position == constraint.seal
		AddressConstraint.Kind.GLYPH_NOT_AT:
			return position != constraint.seal
		AddressConstraint.Kind.EXCLUDED:
			return position == ABSENT
		AddressConstraint.Kind.INCLUDED:
			return position != ABSENT
	var farther: int = _position(sequence, glyphs[1])
	return farther == ABSENT or (position != ABSENT and position < farther)


## Seal number 1..LENGTH of [param glyph], or ABSENT.
func _position(sequence: Array, glyph: int) -> int:
	for index: int in sequence.size():
		if sequence[index] == glyph:
			return index + 1
	return ABSENT


func _same_set(sequence: Array, glyphs: Array[int]) -> bool:
	if glyphs.size() != sequence.size():
		return false
	for glyph: int in glyphs:
		if _position(sequence, glyph) == ABSENT:
			return false
	for glyph: int in sequence:
		if not glyphs.has(glyph):
			return false
	return true


func _brute_force(constraints: Array[AddressConstraint]) -> Array[Array]:
	var fitting: Array[Array] = []
	for sequence: Array in _sequences:
		var fits: bool = true
		for constraint: AddressConstraint in constraints:
			if not _reference_fits(constraint, sequence):
				fits = false
				break
		if fits:
			fitting.append(sequence)
	return fitting


func _glyph() -> int:
	if _rng.randf() < 0.05:
		return _rng.randi_range(0, MAX_DRAWN_GLYPH)
	return ALPHABET[_rng.randi_range(0, ALPHABET.size() - 1)]


## A seeded shuffle (Array.shuffle() would use the global generator).
func _shuffled(glyphs: Array[int]) -> Array[int]:
	var shuffled: Array[int] = glyphs.duplicate()
	for index: int in range(shuffled.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var held: int = shuffled[index]
		shuffled[index] = shuffled[other]
		shuffled[other] = held
	return shuffled


func _seal() -> int:
	return _rng.randi_range(0, LENGTH + 1) if _rng.randf() < 0.05 else _rng.randi_range(1, LENGTH)


func _random_set_glyphs() -> Array[int]:
	var glyphs: Array[int] = _shuffled(ALPHABET)
	var size: int = LENGTH
	var roll: float = _rng.randf()
	if roll < 0.08:
		size += _rng.randi_range(-1, 1)
	glyphs = glyphs.slice(0, size)
	if roll > 0.92:
		glyphs[0] = glyphs[1]
	elif roll > 0.85:
		glyphs[0] = _rng.randi_range(8, MAX_DRAWN_GLYPH)
	return glyphs


func _random_constraint() -> AddressConstraint:
	var kind: int = _rng.randi_range(0, AddressConstraint.Kind.size() - 1)
	if _soft:
		kind = SOFT_KINDS[_rng.randi_range(0, SOFT_KINDS.size() - 1)]
	match kind:
		AddressConstraint.Kind.GLYPH_AT:
			return AddressConstraint.glyph_at(_seal(), _glyph())
		AddressConstraint.Kind.GLYPH_NOT_AT:
			return AddressConstraint.glyph_not_at(_seal(), _glyph())
		AddressConstraint.Kind.EXCLUDED:
			return AddressConstraint.excluded(_glyph())
		AddressConstraint.Kind.INCLUDED:
			return AddressConstraint.included(_glyph())
		AddressConstraint.Kind.EXACT_SET:
			return AddressConstraint.exact_set(_random_set_glyphs())
	var nearer: int = _glyph()
	return AddressConstraint.nearer_than(nearer, nearer if _rng.randf() < 0.05 else _glyph())


func _random_constraints() -> Array[AddressConstraint]:
	var constraints: Array[AddressConstraint] = []
	var size: int = _rng.randi_range(4, 10) if _soft else _rng.randi_range(0, 7)
	for _index: int in size:
		if not constraints.is_empty() and _rng.randf() < 0.12:
			constraints.append(constraints[_rng.randi_range(0, constraints.size() - 1)])
		else:
			constraints.append(_random_constraint())
	if _rng.randf() < 0.02:
		var shapeless := AddressConstraint.included(_glyph())
		shapeless.glyphs.append(_glyph())
		constraints.append(shapeless)
	return constraints


func _describe(constraints: Array[AddressConstraint]) -> String:
	var parts: PackedStringArray = []
	for constraint: AddressConstraint in constraints:
		parts.append(str(constraint.to_dict()))
	return ", ".join(parts)


func _check_list(constraints: Array[AddressConstraint], expected: Array[Array]) -> void:
	var limit: int = expected.size() if expected.size() <= FULL_LIST_MAX else LIST_PREFIX
	var listed: Array[PackedInt32Array] = CandidateCounter.list_in(
		constraints, ALPHABET, LENGTH, limit
	)
	var listed_plain: Array[Array] = []
	for sequence: PackedInt32Array in listed:
		listed_plain.append(Array(sequence))
	(
		assert_array(listed_plain)
		. override_failure_message("list mismatch for [%s]" % _describe(constraints))
		. is_equal(expected.slice(0, limit))
	)


## count_in() equals the brute-force count and list_in() returns exactly the brute-force
## candidates, for SETS seeded random constraint sets of every kind.
func test_counter_matches_brute_force() -> void:
	var hit: Dictionary[String, int] = _cross_check(SETS)
	assert_int(hit["zero"]).is_greater(SETS / 10)
	assert_int(hit["some"]).is_greater(SETS / 3)


## The same cross-check on SOFT_SETS larger sets of order edges and per-seal rules.
func test_counter_matches_brute_force_on_soft_sets() -> void:
	_soft = true
	var hit: Dictionary[String, int] = _cross_check(SOFT_SETS)
	assert_int(hit["some"]).is_greater(SOFT_SETS / 2)


## Cross-checks [param sets] random constraint sets; returns how many had zero, some or all
## candidates.
func _cross_check(sets: int) -> Dictionary[String, int]:
	var hit: Dictionary[String, int] = {"zero": 0, "some": 0, "all": 0}
	for _index: int in sets:
		var constraints: Array[AddressConstraint] = _random_constraints()
		var expected: Array[Array] = _brute_force(constraints)
		var counted: int = CandidateCounter.count_in(constraints, ALPHABET, LENGTH)
		(
			assert_int(counted)
			. override_failure_message(
				"count %d != %d for [%s]" % [counted, expected.size(), _describe(constraints)]
			)
			. is_equal(expected.size())
		)
		_check_list(constraints, expected)
		var bucket: String = "some"
		if expected.is_empty():
			bucket = "zero"
		elif expected.size() == _sequences.size():
			bucket = "all"
		hit[bucket] += 1
	prints("brute-force cross-check buckets:", hit)
	return hit


## list_in() stops at its limit and returns the lexicographically first candidates.
func test_list_in_respects_limit() -> void:
	var constraints: Array[AddressConstraint] = [AddressConstraint.nearer_than(5, 2)]
	var expected: Array[Array] = _brute_force(constraints)
	for limit: int in [0, 1, 7, 50]:
		var listed: Array[PackedInt32Array] = CandidateCounter.list_in(
			constraints, ALPHABET, LENGTH, limit
		)
		assert_int(listed.size()).is_equal(limit)
		for index: int in listed.size():
			assert_array(Array(listed[index])).is_equal(expected[index])


## Hand-made sets aimed at the counter's shortcuts: order cycles, a glyph after more glyphs
## than there are seals, requirement passed up an order chain, interchangeable glyphs, glyphs
## kept off two seals (mask mode) or one (count mode), fragments on one seal, duplicates.
func _adversarial_sets() -> Array[Array]:
	var c := AddressConstraint
	return [
		[c.nearer_than(1, 2), c.nearer_than(2, 3), c.nearer_than(3, 1)],
		[c.nearer_than(1, 2), c.nearer_than(2, 1), c.included(3)],
		[c.nearer_than(1, 0), c.nearer_than(2, 0), c.nearer_than(3, 0), c.nearer_than(4, 0)],
		[c.nearer_than(0, 1), c.nearer_than(1, 2), c.nearer_than(2, 3), c.included(3)],
		[c.nearer_than(0, 1), c.nearer_than(0, 2), c.nearer_than(0, 3), c.nearer_than(0, 4)],
		[c.nearer_than(0, 4), c.nearer_than(1, 4), c.nearer_than(2, 5), c.nearer_than(3, 5)],
		[c.glyph_not_at(1, 5), c.glyph_not_at(3, 5), c.glyph_not_at(2, 6), c.nearer_than(0, 1)],
		[c.glyph_not_at(1, 5), c.glyph_not_at(2, 6), c.glyph_not_at(2, 7), c.included(0)],
		[c.glyph_at(2, 1), c.glyph_at(2, 3)],
		[c.glyph_at(2, 1), c.glyph_at(2, 1), c.nearer_than(1, 2), c.glyph_not_at(3, 2)],
		[c.glyph_at(1, 4), c.nearer_than(3, 4)],
		[c.exact_set([0, 1, 2, 3]), c.nearer_than(3, 2), c.nearer_than(2, 1), c.glyph_not_at(4, 0)],
		[c.exact_set([0, 1, 2, 3]), c.exact_set([3, 2, 1, 0]), c.excluded(4)],
		[c.exact_set([0, 1, 2, 3]), c.exact_set([0, 1, 2, 4])],
		[c.included(0), c.included(1), c.included(2), c.included(3), c.nearer_than(4, 0)],
		[c.included(0), c.included(1), c.included(2), c.included(3), c.included(4)],
		[c.nearer_than(9, 2), c.nearer_than(2, 9), c.glyph_not_at(5, 3), c.glyph_at(0, 4)],
	]


## Each adversarial set gives the brute-force count and list.
func test_adversarial_sets_match_brute_force() -> void:
	for raw: Array in _adversarial_sets():
		var constraints: Array[AddressConstraint] = []
		constraints.assign(raw)
		var expected: Array[Array] = _brute_force(constraints)
		var counted: int = CandidateCounter.count_in(constraints, ALPHABET, LENGTH)
		(
			assert_int(counted)
			. override_failure_message("count for [%s]" % _describe(constraints))
			. is_equal(expected.size())
		)
		_check_list(constraints, expected)
