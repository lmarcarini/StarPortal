## Tests for ResearchTreeLayout: column = prerequisite depth within the category, row = order
## within the column, lines only inside a category, stubs for needs in another one; and the
## real data laid out as the card says.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite


func _def(
	id: StringName, order: int, needs: Array[StringName], category: StringName
) -> ResearchDef:
	var def := ResearchDef.new()
	def.id = id
	def.order = order
	def.needs = needs
	def.category = category
	return def


func _real() -> Array[ResearchDef]:
	var defs: Array[ResearchDef] = []
	defs.assign(ResearchFixture.state(false).research_defs.values())
	return defs


func test_columns_follow_depth_and_rows_follow_order() -> void:
	var defs: Array[ResearchDef] = [
		_def(&"d", 4, [&"b", &"c"], &"x"),
		_def(&"a", 1, [], &"x"),
		_def(&"c", 3, [], &"x"),
		_def(&"b", 2, [&"a"], &"x"),
		_def(&"z", 5, [&"a"], &"y"),
	]
	var cells: Dictionary[StringName, Vector2i] = ResearchTreeLayout.cells(defs, &"x")
	assert_dict(cells).is_equal(
		{&"a": Vector2i(0, 0), &"b": Vector2i(1, 0), &"c": Vector2i(0, 1), &"d": Vector2i(2, 0)}
	)
	defs.reverse()
	assert_dict(ResearchTreeLayout.cells(defs, &"x")).is_equal(cells)
	assert_array(ResearchTreeLayout.edges(defs, &"x")).contains_exactly_in_any_order(
		[[&"a", &"b"], [&"b", &"d"], [&"c", &"d"]]
	)
	assert_dict(ResearchTreeLayout.cells(defs, &"y")).is_equal({&"z": Vector2i(0, 0)})
	assert_array(ResearchTreeLayout.edges(defs, &"y")).is_empty()
	assert_array(ResearchTreeLayout.stubs(defs, defs[0])).is_equal([&"a"])
	assert_dict(ResearchTreeLayout.cells(defs, &"none")).is_empty()


func test_real_tree_matches_the_card() -> void:
	var defs: Array[ResearchDef] = _real()
	(
		assert_dict(ResearchTreeLayout.cells(defs, &"research_construction"))
		. is_equal(
			{
				&"excavation_survey": Vector2i(0, 0),
				&"field_engineering": Vector2i(0, 1),
				&"lift_shaft": Vector2i(1, 0),
				&"deep_excavation": Vector2i(2, 0),
			}
		)
	)
	assert_dict(ResearchTreeLayout.cells(defs, &"research_energy")).is_equal(
		{
			&"second_plant": Vector2i(0, 0),
			&"bank_array": Vector2i(0, 1),
			&"fuel_contracts": Vector2i(1, 0),
			&"later_capacitor_lattice": Vector2i(1, 1)
		}
	)
	assert_dict(ResearchTreeLayout.cells(defs, &"research_gate")).is_empty()
	var alien: Array[ResearchDef] = ResearchTreeLayout.in_category(defs, &"research_alien")
	var staff: Array[ResearchDef] = ResearchTreeLayout.in_category(defs, &"research_staff")
	assert_int(alien.size()).is_equal(1)
	assert_bool(alien[0].is_hidden()).is_true()
	assert_int(staff.size()).is_equal(0)
	for def: ResearchDef in defs:
		assert_array(ResearchTreeLayout.stubs(defs, def)).is_empty()
