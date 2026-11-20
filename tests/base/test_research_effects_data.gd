## Tests for data-driven research effects (M4-21): the seven M2.5 projects unlock exactly what
## the old hard-coded table did, finishing one applies them through the research system, a
## ModifierEffect is allowed in a project but never applied, and no project's effects are
## written in code any more.
## Bible: docs/content/m4-core-systems.md section 7 (1)
extends GdUnitTestSuite

## The table that lived in UnlockRules.PROJECTS before M4.
const OLD_TABLE: Dictionary = {
	&"excavation_survey": [[&"dig_depth", 2], [&"unlock_room", &"room_stairs"]],
	&"lift_shaft": [[&"unlock_room", &"room_lift"]],
	&"deep_excavation": [[&"dig_depth", 4]],
	&"second_plant": [[&"unlock_room", &"room_power_plant"]],
	&"fuel_contracts": [[&"plant_upkeep", 100]],
	&"bank_array": [[&"bank_cap", 3]],
	&"field_engineering": [[&"unlock_room", &"room_workshop"]],
}


func test_projects_match_the_old_table() -> void:
	assert_str(str(UnlockFixture.projects())).is_equal(str(OLD_TABLE))


func test_finishing_applies_the_effects() -> void:
	var state: GameState = ResearchFixture.state(false)
	var def: ResearchDef = state.research_defs[&"excavation_survey"]
	ResearchSystem.finish(state, def, &"")
	assert_int(state.unlocks.dig_depth).is_equal(2)
	assert_bool(state.unlocks.has_room(&"room_stairs")).is_true()


func test_modifier_allowed_but_not_applied() -> void:
	var state: GameState = ResearchFixture.state(false)
	var def: ResearchDef = (state.research_defs[&"bank_array"] as ResearchDef).duplicate(true)
	var modifier := ModifierEffect.new()
	modifier.key = &"research_speed_pct"
	modifier.amount = 10
	def.effects.append(modifier)
	var empty: Dictionary[String, bool] = {}
	var list: Array[ResearchDef] = [def]
	assert_array(ContentCheckResearch.check(list, empty)).is_empty()
	assert_bool(StoryRules.apply(state, modifier, def.id)).is_false()
	assert_int(StoryRules.apply_all(state, def.effects, def.id)).is_equal(1)
	assert_int(state.unlocks.bank_cap).is_equal(3)


func test_no_research_effects_in_code() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/base/unlock_rules.gd")
	assert_str(text).not_contains("PROJECTS")
	assert_str(text).not_contains('&"room_stairs"')
