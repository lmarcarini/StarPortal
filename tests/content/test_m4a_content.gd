## Tests for the M4a test content (M4-18): three factions, HEARTH and TOLLGATE held by the
## Kindred and the Ossar, four requests, and conversations whose every path reaches its End;
## the Committee briefing calls on day 2 of a new game.
## Bible: docs/content/m4-core-systems.md section 8
extends GdUnitTestSuite

var _defs: GameDefs


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func _new_game() -> GameState:
	var state := GameState.new_game(5, _defs.balance)
	GameSetup.build_new(state, _defs)
	return state


func test_content_counts() -> void:
	assert_int(_defs.factions.size()).is_equal(3)
	assert_int(_defs.requests.size()).is_equal(4)
	assert_int(_defs.conversations.size()).is_equal(7)
	var state: GameState = _new_game()
	assert_str(String(state.galaxy.get_world(&"world_hearth").controller)).is_equal(
		"faction_kindred"
	)
	assert_str(String(state.galaxy.get_world(&"world_tollgate").controller)).is_equal(
		"faction_ossar"
	)
	assert_int(state.factions.standing[&"faction_ossar"]).is_equal(-40)
	assert_array(state.factions.met).is_equal([&"faction_committee"])


## Every path through every conversation (each answer at each choice) reaches its End.
func test_every_path_reaches_the_end() -> void:
	for def: ConversationDef in _defs.conversations:
		var none: Array[int] = []
		for path: Array in _paths(def, def.start, none):
			var state: GameState = _new_game()
			state.gate.mode = GateState.RingMode.LOCKED
			assert_bool(ConversationRules.start(state, def.id, def.channels[0], &"")).is_true()
			ConversationDriver.play(state, path)
			var record: TranscriptRecord = state.conversations.transcripts[-1]
			assert_bool(record.cut_off).override_failure_message(String(def.id)).is_false()


## The briefing becomes a pending phone call at the start of day 2.
func test_briefing_calls_on_day_two() -> void:
	var state: GameState = _new_game()
	state.clock.tick = TimeMath.TICKS_PER_DAY
	FactionSystem.new().on_day(state)
	assert_int(state.factions.pending.size()).is_equal(1)
	assert_str(String(state.factions.pending[0].conversation)).is_equal("conv_committee_briefing")
	assert_str(String(state.factions.pending[0].channel)).is_equal("phone")


## The briefing files both addresses and offers the HEARTH survey.
func test_briefing_effects() -> void:
	var state: GameState = _new_game()
	var books: int = state.address_book.entries.size()
	ConversationRules.start(state, &"conv_committee_briefing", &"phone", &"")
	ConversationDriver.play(state)
	assert_int(state.address_book.entries.size()).is_equal(books + 2)
	assert_str(String(state.requests.items[0].request)).is_equal("request_survey_hearth")


func _paths(def: ConversationDef, node_id: StringName, prefix: Array[int]) -> Array[Array]:
	var node: ConversationNodeDef = def.node(node_id)
	var found: Array[Array] = []
	match node.kind:
		ConversationNodeDef.Kind.END:
			found.append(prefix)
		ConversationNodeDef.Kind.LINE:
			found.append_array(_paths(def, node.next, prefix))
		ConversationNodeDef.Kind.CHOICE:
			for index: int in node.choices.size():
				var longer: Array[int] = prefix.duplicate()
				longer.append(index)
				found.append_array(_paths(def, node.choices[index].next, longer))
	return found


## M4-34: three artefacts with the design's values, each reachable in play.
func test_artefacts_and_where_they_come_from() -> void:
	assert_int(_defs.artefacts.size()).is_equal(3)
	var state: GameState = _new_game()
	var effigy: ArtefactDef = state.artefact_defs[&"ossar_effigy"]
	assert_str(String(effigy.storage)).is_equal("containment")
	assert_int(effigy.hazard_chance_pct).is_equal(20)
	assert_int(effigy.modifiers[0].amount).is_equal(-20)
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, &"world_tollgate")
	var found: Array[StringName] = []
	for target: WorldTarget in facts.targets:
		found.append(target.artefact_id)
	assert_array(found).contains([&"ossar_effigy", &"resonant_lattice"])
	var research: RequestDef = state.request_defs[&"request_kindred_research"]
	var gives_loom: bool = false
	for effect: EffectDef in research.reward:
		gives_loom = (
			gives_loom
			or (
				effect is GiveArtefactEffect
				and (effect as GiveArtefactEffect).artefact == &"kindred_loom"
			)
		)
	assert_bool(gives_loom).is_true()


## The hazard drains stored power, never below zero.
func test_effigy_hazard_drains_power() -> void:
	var state: GameState = _new_game()
	state.power.stored_mwh = 30.0
	var effigy: ArtefactDef = state.artefact_defs[&"ossar_effigy"]
	StoryRules.apply_all(state, effigy.hazard, effigy.id)
	assert_float(state.power.stored_mwh).is_equal(10.0)
	StoryRules.apply_all(state, effigy.hazard, effigy.id)
	assert_float(state.power.stored_mwh).is_equal(0.0)


## M4-35: the placeholder tech tree covers every branch and every modifier key.
func test_tech_tree_coverage() -> void:
	var per_branch: Dictionary[StringName, int] = {}
	var keys: Dictionary[StringName, bool] = {}
	var studies: int = 0
	for def: ResearchDef in _defs.research:
		per_branch[def.category] = per_branch.get(def.category, 0) + 1
		for effect: EffectDef in def.effects:
			if effect is ModifierEffect:
				keys[(effect as ModifierEffect).key] = true
			if effect is StudyArtefactEffect:
				studies += 1
	assert_int(per_branch.size()).is_equal(7)
	for branch: StringName in per_branch:
		assert_int(per_branch[branch]).override_failure_message(String(branch)).is_between(4, 7)
	for key: StringName in ModifierEffect.KEYS:
		assert_bool(keys.has(key)).override_failure_message(String(key)).is_true()
	assert_int(studies).is_equal(3)
	assert_int(_defs.research.size()).is_between(34, 42)
