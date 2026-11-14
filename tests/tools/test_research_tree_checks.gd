## Tests for the research tree checks (M4-33): cycles, never-visible needs, orders within a
## branch, revealed ids, and the size report.
extends GdUnitTestSuite


static func _def(id: StringName, needs: Array[StringName], order: int) -> ResearchDef:
	var def := ResearchDef.new()
	def.id = id
	def.needs = needs
	def.order = order
	def.category = &"research_energy"
	return def


func test_cycle() -> void:
	var a: ResearchDef = _def(&"a", [&"b"], 1)
	var b: ResearchDef = _def(&"b", [&"a"], 2)
	var c: ResearchDef = _def(&"c", [], 3)
	var none: Dictionary[StringName, bool] = {}
	var list: Array[ResearchDef] = [a, b, c]
	assert_str("\n".join(ContentCheckResearchTree.check(list, none))).contains("form a cycle")
	list = [c]
	assert_array(ContentCheckResearchTree.check(list, none)).is_empty()


func test_never_visible_need_and_orders() -> void:
	var hidden: ResearchDef = _def(&"hidden", [], 1)
	hidden.reveal = &"hidden"
	hidden.requires = [FactionMetCondition.new()]
	var after: ResearchDef = _def(&"after", [&"hidden"], 1)
	var none: Dictionary[StringName, bool] = {}
	var list: Array[ResearchDef] = [hidden, after]
	var text: String = "\n".join(ContentCheckResearchTree.check(list, none))
	assert_str(text).contains("needs hidden, which can never become visible")
	assert_str(text).contains("repeats")
	var revealed: Dictionary[StringName, bool] = {&"hidden": true}
	assert_str("\n".join(ContentCheckResearchTree.check(list, revealed))).not_contains("never")


func test_revealed_ids_and_report() -> void:
	var reveal := UnlockResearchEffect.new()
	reveal.project = &"hidden"
	var holder: ResearchDef = _def(&"holder", [], 5)
	holder.effects = [reveal]
	var defs: Array[DefBase] = [holder]
	assert_dict(ContentCheckResearchTree.revealed_ids(defs)).is_equal({&"hidden": true})
	var list: Array[ResearchDef] = [_def(&"x", [], 1), _def(&"y", [&"x"], 2), _def(&"z", [&"y"], 3)]
	var lines: Array[String] = ContentCheckResearchTree.report(list)
	assert_str(lines[0]).is_equal("research: research_energy has 3 project(s)")
	assert_str(lines[-1]).is_equal("research: deepest needs chain is 3 project(s)")
