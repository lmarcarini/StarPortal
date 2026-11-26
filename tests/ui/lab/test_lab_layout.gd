## Tests for LabLayout.cells() and LabText (card #560): columns follow shown prerequisites,
## rows follow the first parent and never collide; status lines and short money and hours.
## Bible: docs/content/interface-reference.md section 9
extends GdUnitTestSuite


func _def(id: StringName, needs: Array[StringName] = []) -> ResearchDef:
	var def := ResearchDef.new()
	def.id = id
	def.needs = needs
	return def


func test_cells_follow_prerequisites() -> void:
	var defs: Array[ResearchDef] = [
		_def(&"a"), _def(&"b", [&"a"]), _def(&"c", [&"a"]), _def(&"d"), _def(&"e", [&"hidden"])
	]
	var cells: Dictionary[StringName, Vector2i] = LabLayout.cells(defs)
	assert_that(cells[&"a"]).is_equal(Vector2i(0, 0))
	assert_that(cells[&"b"]).is_equal(Vector2i(1, 0))
	assert_that(cells[&"c"]).is_equal(Vector2i(1, 1))
	assert_that(cells[&"d"]).is_equal(Vector2i(0, 1))
	assert_that(cells[&"e"]).is_equal(Vector2i(0, 2))
	var seen: Dictionary = {}
	for cell: Vector2i in cells.values():
		assert_bool(seen.has(cell)).is_false()
		seen[cell] = true


func test_cells_with_a_child_listed_first() -> void:
	var defs: Array[ResearchDef] = [_def(&"b", [&"a"]), _def(&"a")]
	var cells: Dictionary[StringName, Vector2i] = LabLayout.cells(defs)
	assert_that(cells[&"a"]).is_equal(Vector2i(0, 0))
	assert_that(cells[&"b"]).is_equal(Vector2i(1, 0))


func test_short_texts() -> void:
	assert_str(LabText.hours_short(4)).is_equal("4H")
	assert_str(LabText.hours_short(24)).is_equal("1D")
	assert_str(LabText.hours_short(30)).is_equal("1D 6H")
	assert_str(LabText.money_short(300)).is_equal("$300K")
	assert_str(LabText.money_short(1200)).is_equal("$1.2M")


func test_gives_splits_sentences() -> void:
	var def := ResearchDef.new()
	def.line_key = &"Incoming wormholes show their origin; warnings their objective."
	assert_array(LabText.gives(def)).is_equal(
		["Incoming wormholes show their origin", "Warnings their objective"] as Array[String]
	)


func test_wrap_keeps_rows_within_width() -> void:
	var style: RefText = RefText.make(RefText.LABEL_MEDIUM, 18, Color.WHITE, 1.0)
	var line: String = "The charge gauge shows what a dial needs before you dial"
	var rows: Array[String] = LabPanel.wrap(style, line, 200.0)
	assert_int(rows.size()).is_greater(1)
	assert_str(" ".join(rows)).is_equal(line)
	for row: String in rows:
		assert_float(style.width(row)).is_less_equal(200.0)
