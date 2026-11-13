## Tests for artefact study projects (M4-30): locked with the artefact's reason until held,
## finishing marks every held instance Studied and opens projects that need it, a hand-over
## mid-study pauses it, the content check pairs a study with HasArtefact, and the Archive says
## who studied it.
## Bible: docs/content/m4-core-systems.md sections 5 and 7
extends GdUnitTestSuite

const ARTEFACT: StringName = &"artefact_loom"

var _state: GameState
var _study: ResearchDef


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()
	var artefact := ArtefactDef.new()
	artefact.id = ARTEFACT
	_state.artefact_defs[ARTEFACT] = artefact
	_study = ResearchDef.new()
	_study.id = &"study_loom"
	_study.order = 50
	_study.days = 1
	_study.category = &"research_alien"
	_study.name_key = &"Loom study"
	var held := HasArtefactCondition.new()
	held.artefact = ARTEFACT
	_study.requires = [held]
	var studied := StudyArtefactEffect.new()
	studied.artefact = ARTEFACT
	_study.effects = [studied]
	_state.research_defs[_study.id] = _study
	var follow := ResearchDef.new()
	follow.id = &"loom_weaving"
	follow.order = 51
	follow.needs = [_study.id]
	follow.effects = [ModifierEffect.new()]
	_state.research_defs[follow.id] = follow


func test_locked_until_held_then_studied() -> void:
	assert_str(ResearchText.lock_reason(_state, _study)).is_equal(
		"Requires the artefact artefact_loom"
	)
	StoryRulesItems.give_artefact(_state, ARTEFACT)
	StoryRulesItems.give_artefact(_state, ARTEFACT)
	assert_bool(ResearchRules.is_available(_state, _study)).is_true()
	(
		assert_bool(ResearchRules.is_available(_state, _state.research_defs[&"loom_weaving"]))
		. is_false()
	)
	_state.research.active = _study.id
	ResearchSystem.finish(_state, _study)
	for record: ArtefactRecord in _state.artefacts.items:
		assert_int(record.state).is_equal(ArtefactRecord.ArtefactState.STUDIED)
	assert_bool(ResearchRules.is_available(_state, _state.research_defs[&"loom_weaving"])).is_true()
	assert_str(ArtefactText.describe(_state, _state.artefacts.items[0])).contains(
		"Studied by Loom study"
	)


func test_hand_over_pauses() -> void:
	StoryRulesItems.give_artefact(_state, ARTEFACT)
	_state.research.active = _study.id
	var system := ResearchSystem.new()
	_state.base.add_room(&"room_research_lab", 1, Vector2i(30, 2))
	var take := TakeArtefactEffect.new()
	take.artefact = ARTEFACT
	StoryRules.apply(_state, take, &"x")
	var before: int = _state.research.ticks_done
	for tick: int in 20:
		system.tick(_state)
	assert_int(_state.research.ticks_done).is_equal(before)


func test_content_check_pairs_study_with_has_artefact() -> void:
	var empty: Dictionary[String, bool] = {}
	var bad: ResearchDef = _study.duplicate(true)
	bad.requires = []
	var list: Array[ResearchDef] = [bad]
	assert_str("\n".join(ContentCheckResearch.check(list, empty))).contains(
		"studies 'artefact_loom' but does not require HasArtefact"
	)
	list = [_study]
	assert_array(ContentCheckResearch.check(list, empty)).is_empty()
