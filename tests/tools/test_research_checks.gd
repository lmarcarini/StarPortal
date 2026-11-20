## Tests for ContentCheckResearch and ResearchDef's own content errors: bad effects, projects
## needs later in the list, missing keys, locked slots
## with a cost, and the real content passing.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite


func _real() -> Array[ResearchDef]:
	var list: Array[ResearchDef] = []
	list.assign(ResearchFixture.state(false).research_defs.values())
	return list


func _copy(id: StringName) -> ResearchDef:
	for def: ResearchDef in _real():
		if def.id == id:
			return def.duplicate(true)
	return null


func _without(id: StringName, extra: ResearchDef) -> Array[ResearchDef]:
	var list: Array[ResearchDef] = []
	for def: ResearchDef in _real():
		if def.id != id:
			list.append(def)
	list.append(extra)
	return list


## The real research content has no problems.
func test_real_content_passes() -> void:
	var empty: Dictionary[String, bool] = {}
	assert_array(ContentCheckResearch.check(_real(), empty)).is_empty()
	var defs: Dictionary[StringName, DefBase] = {}
	for def: ResearchDef in _real():
		defs[def.id] = def
	for def: ResearchDef in _real():
		assert_array(def.get_content_errors(defs)).is_empty()


## An empty effect or an unlock value UnlockRules refuses is reported; a ModifierEffect is
## allowed.
func test_bad_effects() -> void:
	var empty: Dictionary[String, bool] = {}
	var def: ResearchDef = _copy(&"bank_array")
	var cap := BankCapEffect.new()
	cap.count = -2
	def.effects = [cap]
	var errors: Array[String] = ContentCheckResearch.check(_without(&"bank_array", def), empty)
	assert_str("\n".join(errors)).contains("bad effect")
	var room := UnlockRoomEffect.new()
	def.effects = [room, ModifierEffect.new()]
	errors = ContentCheckResearch.check(_without(&"bank_array", def), empty)
	assert_int(errors.size()).is_equal(1)


## A need later in the list, a duplicate order and a missing key are reported.
func test_order_and_keys() -> void:
	var def: ResearchDef = _copy(&"excavation_survey")
	def.needs.assign([&"bank_array"])
	var keys: Dictionary[String, bool] = {"RESEARCH_EXCAVATION_SURVEY_NAME": true}
	var errors: Array[String] = ContentCheckResearch.check([def, _copy(&"bank_array")], keys)
	var text: String = "\n".join(errors)
	assert_str(text).contains("comes later").contains("is in no table")
	var twin: ResearchDef = _copy(&"lift_shaft")
	twin.order = def.order
	assert_str("\n".join(ContentCheckResearch.check([def, twin], {}))).contains("also used by")


## ResearchDef reports a need on itself or on a locked slot, and a locked slot with a cost.
func test_def_content_errors() -> void:
	var category := ResearchCategoryDef.new()
	var def: ResearchDef = _copy(&"lift_shaft")
	def.needs.assign([&"lift_shaft", &"research_construction"])
	var defs: Dictionary[StringName, DefBase] = {def.id: def, &"research_construction": category}
	assert_array(def.get_content_errors(defs)).has_size(2)
	def.needs.clear()
	def.discipline = &"sometimes"
	assert_array(def.get_content_errors(defs)).has_size(1)


## Every real def names a known category; an unknown or missing category, a category that is
## not a ResearchCategoryDef, a duplicate category order and a missing key are reported.
func test_categories() -> void:
	var categories: Array[ResearchCategoryDef] = []
	categories.assign(ResearchView.categories())
	assert_int(categories.size()).is_equal(7)
	var empty: Dictionary[String, bool] = {}
	assert_array(ContentCheckResearch.check_categories(_real(), categories, empty)).is_empty()
	var def: ResearchDef = _copy(&"bank_array")
	def.category = &"research_teleport"
	var twin: ResearchCategoryDef = categories[0].duplicate()
	twin.id = &"research_twin"
	categories.append(twin)
	var keys: Dictionary[String, bool] = {"RESEARCH_CAT_ENERGY": true}
	var text: String = "\n".join(ContentCheckResearch.check_categories([def], categories, keys))
	assert_str(text).contains("unknown category").contains("is taken").contains("no table")
	var defs: Dictionary[StringName, DefBase] = {
		def.id: def, &"research_teleport": _copy(&"lift_shaft")
	}
	assert_str("\n".join(def.get_content_errors(defs))).contains("not a research category")
	var categorised: ResearchDef = _copy(&"lift_shaft")
	categorised.category = &"research_construction"
	assert_array(categorised.get_references()).contains([&"research_construction"])
