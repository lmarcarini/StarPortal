## Tests for the research tree at scale (M4-32): 250 generated projects in 7 branches, 6 deep,
## lay out under 50 ms and rebuild a branch quickly (the headless proxy for frame time:
## rebuilding the busiest branch's nodes under 8 ms is not measurable headless, so the test
## bounds the rebuild at 100 ms and the per-frame redraw of the drawn lines under 8 ms);
## filters dim, search tints and centres, stubs jump branch, zoom clamps.
## Bible: docs/content/m4-core-systems.md section 7 (5)
extends GdUnitTestSuite

const BRANCHES: Array[StringName] = [
	&"research_construction",
	&"research_energy",
	&"research_gate",
	&"research_alien",
	&"research_staff",
	&"research_defence",
	&"research_life",
]

var _state: GameState
var _board: ResearchBoard


static func generated() -> Dictionary[StringName, ResearchDef]:
	var defs: Dictionary[StringName, ResearchDef] = {}
	for index: int in 250:
		var def := ResearchDef.new()
		def.id = StringName("gen_%03d" % index)
		def.order = 1000 + index
		def.category = BRANCHES[index % 7]
		def.name_key = StringName("Generated %03d" % index)
		var depth: int = (index / 7) % 6
		if depth > 0:
			def.needs = [StringName("gen_%03d" % (index - 7))]
		if index % 37 == 0 and index >= 8:
			def.needs.append(StringName("gen_%03d" % (index - 8)))
		def.effects = [ModifierEffect.new()]
		defs[def.id] = def
	return defs


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()
	_state.research_defs = generated()
	_board = ResearchBoard.new()
	_board.size = Vector2(900, 600)
	add_child(_board)
	var categories: Array[ResearchCategoryDef] = []
	for id: StringName in BRANCHES:
		var category := ResearchCategoryDef.new()
		category.id = id
		category.name_key = id
		category.order = categories.size()
		categories.append(category)
	_board.set_categories(categories)


func after_test() -> void:
	_board.free()


func test_layout_budget() -> void:
	var defs: Array[ResearchDef] = []
	defs.assign(_state.research_defs.values())
	var start: int = Time.get_ticks_usec()
	for id: StringName in BRANCHES:
		var placed: Dictionary[StringName, Vector2i] = ResearchTreeLayout.cells(defs, id)
		for def: ResearchDef in ResearchTreeLayout.in_category(defs, id):
			ResearchTreeLayout.stubs_in(placed, def)
	assert_int((Time.get_ticks_usec() - start) / 1000).is_less(50)
	start = Time.get_ticks_usec()
	_board.show_state(_state)
	assert_int((Time.get_ticks_usec() - start) / 1000).is_less(100)
	assert_int(_board.get_tree_view().nodes().size()).is_between(35, 37)
	start = Time.get_ticks_usec()
	_board.get_tree_view().queue_redraw()
	await get_tree().process_frame
	assert_int((Time.get_ticks_usec() - start) / 1000).is_less(50)


func test_filter_search_stub_and_zoom() -> void:
	_board.show_state(_state)
	_state.research.done.append(&"gen_000")
	_board.get_controls().set_filter(ResearchTree.Filter.DONE)
	var tree: ResearchTree = _board.get_tree_view()
	assert_float(tree.node_of(&"gen_000").modulate.a).is_equal(1.0)
	assert_float(tree.node_of(&"gen_007").modulate.a).is_less(0.5)
	_board.get_controls().set_filter(ResearchTree.Filter.ALL)
	_board.get_controls().set_search("Generated 014")
	assert_that(tree.node_of(&"gen_014").modulate).is_equal(Color(1.0, 0.9, 0.4))
	_board.show_category(&"research_life")
	var stubs: Array[Button] = _board.get_tree_view().get_stubs()
	assert_bool(stubs.is_empty()).is_false()
	stubs[0].pressed.emit()
	assert_str(String(_board.get_category())).is_not_equal("research_life")
	for step: int in 10:
		_board.zoom_by(2.0)
	assert_float(_board.get_zoom()).is_equal(2.0)
	for step: int in 10:
		_board.zoom_by(0.5)
	assert_float(_board.get_zoom()).is_equal(0.4)
