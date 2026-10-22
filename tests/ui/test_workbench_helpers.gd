## Tests for the Address Workbench's pure helpers: digit grouping, the edits that build a new
## constraint list, the click-to-pick state machine and the plain-words sentences.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const HERON: int = 0
const ANVIL: int = 1

var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)


func test_group_inserts_a_separator_every_three_digits() -> void:
	assert_str(DigitGrouping.group(0, ",")).is_equal("0")
	assert_str(DigitGrouping.group(999, ",")).is_equal("999")
	assert_str(DigitGrouping.group(1000, ",")).is_equal("1,000")
	assert_str(DigitGrouping.group(5040, ".")).is_equal("5.040")
	assert_str(DigitGrouping.group(33891580800, ",")).is_equal("33,891,580,800")
	assert_str(DigitGrouping.group(33891580800, ".")).is_equal("33.891.580.800")
	assert_str(DigitGrouping.group(-1234567, ",")).is_equal("-1,234,567")
	assert_str(DigitGrouping.group(-9223372036854775807 - 1, ",")).is_equal(
		"-9,223,372,036,854,775,808"
	)


func test_number_uses_the_locale_separator() -> void:
	TranslationServer.set_locale("en")
	assert_str(WorkbenchText.number(33891580800, tr)).is_equal("33,891,580,800")
	TranslationServer.set_locale("pt_BR")
	assert_str(WorkbenchText.number(33891580800, tr)).is_equal("33.891.580.800")


func test_placing_moves_the_glyph_and_replaces_the_seal() -> void:
	var start: Array[AddressConstraint] = [AddressConstraint.glyph_at(2, HERON)]
	var moved: Array[AddressConstraint] = WorkbenchEdits.placed(start, 5, HERON)
	assert_int(moved.size()).is_equal(1)
	assert_bool(moved[0].equals(AddressConstraint.glyph_at(5, HERON))).is_true()
	var replaced: Array[AddressConstraint] = WorkbenchEdits.placed(moved, 5, ANVIL)
	assert_int(replaced.size()).is_equal(1)
	assert_int(WorkbenchEdits.glyph_at_seal(replaced, 5)).is_equal(ANVIL)
	assert_bool(start[0].equals(AddressConstraint.glyph_at(2, HERON))).is_true()


func test_edits_never_change_their_input() -> void:
	var start: Array[AddressConstraint] = [AddressConstraint.included(HERON)]
	var before: Array = start.map(func(c: AddressConstraint) -> Dictionary: return c.to_dict())
	WorkbenchEdits.toggled_excluded(start, HERON)
	WorkbenchEdits.with_added(start, AddressConstraint.excluded(ANVIL))
	WorkbenchEdits.without_index(start, 0)
	var after: Array = start.map(func(c: AddressConstraint) -> Dictionary: return c.to_dict())
	assert_array(after).is_equal(before)
	assert_object(WorkbenchEdits.copy(start)[0]).is_not_same(start[0])


func test_rule_out_and_include_toggle_and_replace_each_other() -> void:
	var empty: Array[AddressConstraint] = []
	var ruled: Array[AddressConstraint] = WorkbenchEdits.toggled_excluded(empty, HERON)
	assert_int(WorkbenchEdits.glyph_status(ruled, HERON)).is_equal(
		WorkbenchEdits.GlyphStatus.RULED_OUT
	)
	var included: Array[AddressConstraint] = WorkbenchEdits.toggled_included(ruled, HERON)
	assert_int(included.size()).is_equal(1)
	assert_int(WorkbenchEdits.glyph_status(included, HERON)).is_equal(
		WorkbenchEdits.GlyphStatus.IN_ADDRESS
	)
	assert_array(WorkbenchEdits.toggled_included(included, HERON)).is_empty()
	assert_array(WorkbenchEdits.toggled_excluded(ruled, HERON)).is_empty()


func test_with_added_skips_duplicates() -> void:
	var once: Array[AddressConstraint] = [AddressConstraint.nearer_than(HERON, ANVIL)]
	var twice: Array[AddressConstraint] = WorkbenchEdits.with_added(
		once, AddressConstraint.nearer_than(HERON, ANVIL)
	)
	assert_int(twice.size()).is_equal(1)


func test_group_needs_exactly_seven_included() -> void:
	var constraints: Array[AddressConstraint] = [AddressConstraint.excluded(30)]
	for glyph: int in 6:
		constraints.append(AddressConstraint.included(glyph))
	assert_bool(WorkbenchEdits.can_group(constraints)).is_false()
	assert_int(WorkbenchEdits.grouped_as_set(constraints).size()).is_equal(7)
	constraints.append(AddressConstraint.included(6))
	var grouped: Array[AddressConstraint] = WorkbenchEdits.grouped_as_set(constraints)
	assert_int(grouped.size()).is_equal(2)
	assert_bool(grouped[1].equals(AddressConstraint.exact_set([0, 1, 2, 3, 4, 5, 6]))).is_true()
	assert_int(WorkbenchEdits.glyph_status(grouped, 3)).is_equal(
		WorkbenchEdits.GlyphStatus.IN_ADDRESS
	)


func test_without_index_ignores_out_of_range() -> void:
	var one: Array[AddressConstraint] = [AddressConstraint.included(HERON)]
	assert_int(WorkbenchEdits.without_index(one, 3).size()).is_equal(1)
	assert_int(WorkbenchEdits.without_index(one, -1).size()).is_equal(1)
	assert_array(WorkbenchEdits.without_index(one, 0)).is_empty()


func test_picker_modes() -> void:
	var picker := WorkbenchPicker.new()
	picker.await_not_at()
	assert_int(picker.mode).is_equal(WorkbenchPicker.Mode.IDLE)
	picker.pick(HERON)
	assert_int(picker.mode).is_equal(WorkbenchPicker.Mode.GLYPH_PICKED)
	picker.pick(ANVIL)
	assert_int(picker.glyph).is_equal(ANVIL)
	picker.await_farther()
	assert_int(picker.mode).is_equal(WorkbenchPicker.Mode.AWAIT_FARTHER)
	picker.cancel()
	assert_bool(picker.has_glyph()).is_false()
	picker.pick(HERON)
	picker.pick(HERON)
	assert_int(picker.mode).is_equal(WorkbenchPicker.Mode.IDLE)
	assert_int(picker.glyph).is_equal(-1)


func test_describe_uses_glyph_names_in_both_locales() -> void:
	TranslationServer.set_locale("en")
	var heron: String = tr(WorkbenchText.glyph_name_key(HERON))
	var anvil: String = tr(WorkbenchText.glyph_name_key(ANVIL))
	assert_str(heron).is_equal("Heron")
	assert_str(WorkbenchText.describe(AddressConstraint.glyph_at(2, HERON), tr)).is_equal(
		"Heron is at seal 2"
	)
	assert_str(WorkbenchText.describe(AddressConstraint.nearer_than(ANVIL, HERON), tr)).is_equal(
		"%s is nearer than %s" % [anvil, heron]
	)
	assert_str(WorkbenchText.describe(AddressConstraint.excluded(HERON), tr)).is_equal(
		"Heron is not in the address"
	)
	var set_text: String = WorkbenchText.describe(
		AddressConstraint.exact_set([0, 1, 2, 3, 4, 5, 6]), tr
	)
	assert_str(set_text).contains("Heron, %s, " % anvil)
	TranslationServer.set_locale("pt_BR")
	assert_str(WorkbenchText.describe(AddressConstraint.glyph_not_at(3, HERON), tr)).is_equal(
		"Garça não está no selo 3"
	)
