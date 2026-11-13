## Tests for research requirements and hidden projects (M4-29): requires beyond needs, hidden
## until available or revealed, shown locked with the reason, CompleteResearch on a hidden
## project, and unknown saved ids dropped on load.
## Bible: docs/content/m4-core-systems.md section 7 (2, 3)
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ResearchFixture.state()


func _def() -> ResearchDef:
	return _state.research_defs[&"later_containment"]


func test_hidden_until_available() -> void:
	assert_bool(ResearchRules.is_visible(_state, _def())).is_false()
	assert_array(ResearchRules.visible_projects(_state)).not_contains([_def()])
	FactionRules.meet(_state, &"faction_kindred")
	assert_bool(ResearchRules.is_available(_state, _def())).is_true()
	assert_bool(ResearchRules.is_visible(_state, _def())).is_true()


func test_revealed_but_locked_shows_reason() -> void:
	TranslationServer.set_locale("en")
	_state.research.revealed.append(_def().id)
	assert_bool(ResearchRules.is_visible(_state, _def())).is_true()
	assert_int(ResearchText.kind(_state, _def())).is_equal(ResearchText.Kind.LOCKED)
	assert_str(ResearchText.lock_reason(_state, _def())).starts_with("Requires contact with")
	var result: CommandResult = ResearchRules.can_start(_state, _def().id)
	assert_str(String(result.error_code)).is_equal("requirement_unmet")
	assert_str(ResearchText.refusal(result, _state)).starts_with("Requires contact with")


func test_locked_reveal_is_drawn() -> void:
	var lattice: ResearchDef = _state.research_defs[&"later_capacitor_lattice"]
	assert_bool(lattice.is_hidden()).is_false()
	assert_bool(ResearchRules.is_visible(_state, lattice)).is_true()
	assert_bool(ResearchRules.is_available(_state, lattice)).is_false()


func test_complete_research_on_a_hidden_project() -> void:
	var effect := CompleteResearchEffect.new()
	effect.project = _def().id
	assert_bool(StoryRules.apply(_state, effect, &"x")).is_true()
	assert_bool(ResearchRules.is_visible(_state, _def())).is_true()
	assert_bool(_state.unlocks.has_room(&"room_containment")).is_true()


func test_unknown_ids_dropped_on_load() -> void:
	_state.research.done.append(&"later_fission_plant")
	_state.research.queue.append(&"gone_project")
	_state.research.active = &"also_gone"
	_state.research.ticks_done = 50
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	GameSetup.build(loaded, GameDefs.from_registry(Registry))
	assert_array(loaded.research.done).not_contains([&"later_fission_plant"])
	assert_array(loaded.research.queue).is_empty()
	assert_str(String(loaded.research.active)).is_empty()
	assert_int(loaded.research.ticks_done).is_equal(0)
