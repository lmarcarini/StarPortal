## Tests for CandidateCounter on the real 35-glyph alphabet: the headline counts, origin
## handling, list() order and limit, is_satisfied() and the time budget.
## Bible: gate-and-address-spec.md#player-tools, gate-and-address-spec.md#puzzle-tuning-rules,
## gate-and-address-spec.md#clue-types-and-reliability
extends GdUnitTestSuite

const ORIGIN: int = 5
## 35 * 34 * 33 * 32 * 31 * 30 * 29.
const ALL_ADDRESSES: int = 33_891_580_800
const SKY: Array[int] = [3, 17, 0, 22, 9, 14, 30]
## Local budget from the card is 50 ms; the assertion leaves a CI margin.
const BUDGET_USEC: int = 250_000
## Glyphs outside the heavy sets' order clues (and not the origin), given per-seal rules.
const OTHERS: Array[int] = [0, 1, 2, 3, 4, 6, 7, 8, 9, 16, 17, 18, 19, 26, 27, 28, 29, 30]


func _sky_ordered() -> Array[AddressConstraint]:
	var constraints: Array[AddressConstraint] = [AddressConstraint.exact_set(SKY)]
	for index: int in SKY.size() - 1:
		constraints.append(AddressConstraint.nearer_than(SKY[index], SKY[index + 1]))
	return constraints


## No constraints: every 7-glyph sequence without the origin.
func test_no_constraints_counts_everything() -> void:
	var none: Array[AddressConstraint] = []
	assert_int(CandidateCounter.count(none, ORIGIN)).is_equal(ALL_ADDRESSES)


## One sky chart leaves 7! = 5,040 orderings; six chained order clues leave one.
func test_sky_chart_and_order() -> void:
	var sky: Array[AddressConstraint] = [AddressConstraint.exact_set(SKY)]
	assert_int(CandidateCounter.count(sky, ORIGIN)).is_equal(5040)
	assert_int(CandidateCounter.count(_sky_ordered(), ORIGIN)).is_equal(1)
	var listed: Array[GateAddress] = CandidateCounter.list(_sky_ordered(), ORIGIN, 10)
	assert_int(listed.size()).is_equal(1)
	assert_array(listed[0].coordinates).is_equal(SKY)
	assert_int(listed[0].origin).is_equal(ORIGIN)


## The origin claimed present gives zero; claimed absent changes nothing.
func test_origin_constraints() -> void:
	var at: Array[AddressConstraint] = [AddressConstraint.glyph_at(1, ORIGIN)]
	var included: Array[AddressConstraint] = [AddressConstraint.included(ORIGIN)]
	var with_origin: Array[int] = SKY.duplicate()
	with_origin[6] = ORIGIN
	var in_set: Array[AddressConstraint] = [AddressConstraint.exact_set(with_origin)]
	var absent: Array[AddressConstraint] = [AddressConstraint.excluded(ORIGIN)]
	assert_int(CandidateCounter.count(at, ORIGIN)).is_equal(0)
	assert_int(CandidateCounter.count(included, ORIGIN)).is_equal(0)
	assert_int(CandidateCounter.count(in_set, ORIGIN)).is_equal(0)
	assert_int(CandidateCounter.count(absent, ORIGIN)).is_equal(ALL_ADDRESSES)
	assert_array(CandidateCounter.list(at, ORIGIN, 5)).is_empty()


## An origin that is not a glyph gives no addresses.
func test_bad_origin() -> void:
	var none: Array[AddressConstraint] = []
	assert_int(CandidateCounter.count(none, -1)).is_equal(0)
	assert_int(CandidateCounter.count(none, GateAddress.GLYPH_COUNT)).is_equal(0)
	assert_array(CandidateCounter.list(none, GateAddress.GLYPH_COUNT, 3)).is_empty()


## Contradictions (a planted lie) leave zero.
func test_contradictions_give_zero() -> void:
	var cycle: Array[AddressConstraint] = [
		AddressConstraint.included(3),
		AddressConstraint.nearer_than(3, 17),
		AddressConstraint.nearer_than(17, 3),
	]
	var two_at_one_seal: Array[AddressConstraint] = [
		AddressConstraint.glyph_at(2, 3), AddressConstraint.glyph_at(2, 17)
	]
	var excluded_at: Array[AddressConstraint] = [
		AddressConstraint.glyph_at(4, 9), AddressConstraint.excluded(9)
	]
	var sky_lie: Array[AddressConstraint] = _sky_ordered()
	sky_lie.append(AddressConstraint.glyph_at(1, SKY[1]))
	for constraints: Array[AddressConstraint] in [cycle, two_at_one_seal, excluded_at, sky_lie]:
		assert_int(CandidateCounter.count(constraints, ORIGIN)).is_equal(0)


## Fragments: one glyph pinned leaves 34 * 33 * ... * 29; another kept off a seal removes
## the sequences with it there.
func test_fragment_counts() -> void:
	var pinned: Array[AddressConstraint] = [AddressConstraint.glyph_at(2, 14)]
	var pinned_count: int = 34 * 33 * 32 * 31 * 30 * 29
	assert_int(CandidateCounter.count(pinned, ORIGIN)).is_equal(pinned_count)
	var kept_off: Array[AddressConstraint] = [AddressConstraint.glyph_not_at(3, 14)]
	assert_int(CandidateCounter.count(kept_off, ORIGIN)).is_equal(ALL_ADDRESSES - pinned_count)
	var included: Array[AddressConstraint] = [AddressConstraint.included(14)]
	assert_int(CandidateCounter.count(included, ORIGIN)).is_equal(7 * pinned_count)


## list() returns the lexicographically first fitting addresses, each fitting, up to the limit.
func test_list_order_and_limit() -> void:
	var sky: Array[AddressConstraint] = [AddressConstraint.exact_set(SKY)]
	var listed: Array[GateAddress] = CandidateCounter.list(sky, ORIGIN, 4)
	assert_int(listed.size()).is_equal(4)
	assert_array(listed[0].coordinates).is_equal([0, 3, 9, 14, 17, 22, 30])
	assert_array(listed[1].coordinates).is_equal([0, 3, 9, 14, 17, 30, 22])
	assert_array(listed[2].coordinates).is_equal([0, 3, 9, 14, 22, 17, 30])
	for address: GateAddress in listed:
		assert_bool(address.is_well_formed()).is_true()
		assert_bool(CandidateCounter.is_satisfied(address, sky)).is_true()
	var none: Array[AddressConstraint] = []
	var first: Array[GateAddress] = CandidateCounter.list(none, ORIGIN, 2)
	assert_array(first[0].coordinates).is_equal([0, 1, 2, 3, 4, 6, 7])
	assert_array(first[1].coordinates).is_equal([0, 1, 2, 3, 4, 6, 8])
	assert_array(CandidateCounter.list(sky, ORIGIN, 0)).is_empty()


## is_satisfied() needs every constraint; null address or constraint never fits.
func test_is_satisfied() -> void:
	var address := GateAddress.create(SKY, ORIGIN)
	assert_bool(CandidateCounter.is_satisfied(address, _sky_ordered())).is_true()
	var none: Array[AddressConstraint] = []
	assert_bool(CandidateCounter.is_satisfied(address, none)).is_true()
	var lie: Array[AddressConstraint] = _sky_ordered()
	lie.append(AddressConstraint.excluded(SKY[3]))
	assert_bool(CandidateCounter.is_satisfied(address, lie)).is_false()
	assert_bool(CandidateCounter.is_satisfied(null, none)).is_false()
	var with_null: Array[AddressConstraint] = [null]
	assert_bool(CandidateCounter.is_satisfied(address, with_null)).is_false()
	assert_int(CandidateCounter.count(with_null, ORIGIN)).is_equal(0)


func _pairs() -> Array[AddressConstraint]:
	var constraints: Array[AddressConstraint] = []
	for pair: int in 6:
		constraints.append(AddressConstraint.nearer_than(10 + pair, 20 + pair))
	return constraints


## Each of OTHERS kept off one seal (or [param rules_each] seals), in turn.
func _seal_rules(rules_each: int, glyph_count: int) -> Array[AddressConstraint]:
	var constraints: Array[AddressConstraint] = []
	for index: int in glyph_count:
		for rule: int in rules_each:
			var seal: int = 1 + (index + 3 * rule) % 7
			constraints.append(AddressConstraint.glyph_not_at(seal, OTHERS[index]))
	return constraints


## Heavy but legal sets: 12 glyphs in order clues (six pairs, or one before eleven), and the
## rest of up to 30 constraints per-seal rules on other glyphs, inclusions, an exclusion and a
## fragment. Every glyph with a rule is different, the counter's worst case.
func _heavy_sets() -> Array[Array]:
	var included: Array[AddressConstraint] = _pairs()
	included.append(AddressConstraint.included(10))
	included.append(AddressConstraint.included(21))
	included.append_array(_seal_rules(1, OTHERS.size()))
	var fragment: Array[AddressConstraint] = _pairs()
	fragment.append(AddressConstraint.excluded(31))
	fragment.append(AddressConstraint.glyph_at(7, 33))
	fragment.append_array(_seal_rules(1, OTHERS.size()))
	var two_rules: Array[AddressConstraint] = _pairs()
	two_rules.append_array(_seal_rules(2, 12))
	var star: Array[AddressConstraint] = []
	for leaf: int in 11:
		star.append(AddressConstraint.nearer_than(10, 11 + leaf))
	star.append_array(_seal_rules(1, OTHERS.size()))
	return [included, fragment, two_rules, star]


## Every heavy set is counted within the budget, and the counts are sane.
func test_count_is_fast() -> void:
	for constraints: Array[AddressConstraint] in _heavy_sets():
		assert_int(constraints.size()).is_less_equal(30)
		var started: int = Time.get_ticks_usec()
		var counted: int = CandidateCounter.count(constraints, ORIGIN)
		var elapsed: int = Time.get_ticks_usec() - started
		prints("CandidateCounter.count heavy set: %d in %.1f ms" % [counted, elapsed / 1000.0])
		assert_int(counted).is_greater(0)
		assert_int(counted).is_less(ALL_ADDRESSES)
		assert_int(elapsed).is_less(BUDGET_USEC)
