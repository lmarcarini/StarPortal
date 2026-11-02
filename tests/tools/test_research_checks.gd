## Tests for ContentCheckResearch and ResearchDef's own content errors: bad effects, projects
## out of step with UnlockRules.PROJECTS, needs later in the list, missing keys, locked slots
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


## An unknown effect id, a bad value and effects that differ from UnlockRules are reported.
func test_bad_effects() -> void:
	var empty: Dictionary[String, bool] = {}
	var def: ResearchDef = _copy(&"bank_array")
	def.effects = [[&"teleport", 3]]
	var errors: Array[String] = ContentCheckResearch.check(_without(&"bank_array", def), empty)
	assert_str("\n".join(errors)).contains("bad effect").contains("differ")
	def.effects = [[&"bank_cap", -2]]
	errors = ContentCheckResearch.check(_without(&"bank_array", def), empty)
	assert_str("\n".join(errors)).contains("bad effect")


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
	var locked: ResearchDef = _copy(&"later_fission_plant")
	var def: ResearchDef = _copy(&"lift_shaft")
	def.needs.assign([&"lift_shaft", &"later_fission_plant"])
	var defs: Dictionary[StringName, DefBase] = {def.id: def, locked.id: locked}
	assert_array(def.get_content_errors(defs)).has_size(2)
	locked.cost_k = 10
	assert_array(locked.get_content_errors(defs)).has_size(1)
