## M7-05b: the Xenotech (X01-X06) and Xenobiology (B01-B07) projects and their effects.
## Bible: docs/content/research-and-progression.md section 10
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _state: GameState


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()


func _done(project: StringName) -> void:
	_state.research.revealed.append(project)
	ResearchSystem.finish(_state, _state.research_defs[project], &"")


func _shown(discipline: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for def: ResearchDef in ResearchRules.visible_projects(_state, discipline):
		found.append(def.id)
	return found


func test_xenotech_shows_a_study_per_artefact_held() -> void:
	ResearchFixture.bench_for(_state, &"xenotech")
	assert_array(_shown(&"xenotech")).is_empty()
	StoryRulesItems.give_artefact(_state, &"kindred_loom")
	assert_array(_shown(&"xenotech")).is_equal([&"study_kindred_loom"])
	ResearchFixture.finish(_state, &"study_kindred_loom")
	assert_array(_shown(&"xenotech")).not_contains([&"loom_translator"])
	_state.research.done.append(&"xenolinguistics")
	assert_array(_shown(&"xenotech")).contains([&"loom_translator"])
	assert_array(_shown(&"xenotech")).not_contains([&"alien_weapon_copy", &"anterite_cells"])


func test_a_studied_artefact_hazard_is_controlled() -> void:
	var record := ArtefactRecord.new()
	record.state = ArtefactRecord.ArtefactState.STUDIED
	assert_bool(ArtefactSystem._controlled(record)).is_true()


func test_lattice_recharges_and_capacitor_lattice_doubles_capacity() -> void:
	PowerFixture.add_bank(_state)
	_state.power.stored_mwh = 0.0
	StoryRulesItems.give_artefact(_state, XenoPerks.LATTICE)
	assert_float(XenoPerks.recharge(_state)).is_equal(0.0)
	_done(&"lattice_harmonics")
	assert_float(XenoPerks.recharge(_state)).is_equal(XenoPerks.LATTICE_MWH)
	var capacity: float = PowerRules.capacity_mwh(_state)
	_done(&"capacitor_lattice")
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(capacity * 2.0)


func test_effigy_wards_and_loom_translator() -> void:
	assert_int(XenoPerks.warning_ticks(_state, 30)).is_equal(30)
	_done(&"effigy_wards")
	assert_int(XenoPerks.warning_ticks(_state, 30)).is_equal(60)
	var rubbing: DocumentDef = Registry.get_def(&"doc_lintel_rubbing") as DocumentDef
	_done(&"loom_translator")
	assert_str(DocumentText.gloss(rubbing, _state)).contains("Kindred text, translated")


func test_xenobiology_spends_specimens_and_heals() -> void:
	ResearchFixture.bench_for(_state, &"xenobiology")
	assert_array(_shown(&"xenobiology")).is_equal([&"specimen_analysis"])
	var refused: CommandResult = ResearchRules.can_start(_state, &"specimen_analysis")
	assert_str(String(refused.error_code)).is_equal("needs_specimens")
	_done(&"field_medicine")
	var setback: FieldEventDef.Setback = FieldEventDef.Setback.SERIOUS
	assert_int(XenoPerks.field_injury(_state, setback)).is_equal(FieldEventDef.Setback.LIGHT)
	var person := PersonState.new()
	person.injury = PersonState.Injury.SERIOUS
	assert_int(XenoPerks.recovery_speed(_state, person, 3)).is_equal(3)
	_done(&"regenerative_compounds")
	assert_int(XenoPerks.recovery_speed(_state, person, 3)).is_equal(6)
	_done(&"alien_physiology")
	assert_bool(ResearchPerks.has(_state, XenoPerks.ALIEN_PHYSIOLOGY)).is_true()


func test_specimen_analysis_shows_life_and_toxin_resistance_lowers_biohazard() -> void:
	_state.galaxy = ProbeFixture.galaxy()
	_done(&"specimen_analysis")
	for world: WorldRecord in _state.galaxy.all_worlds():
		if SpecimenRules.add(_state, world.id) >= 0:
			var report: WorldReport = _state.worlds.reports.get(world.id)
			assert_object(report).is_not_null()
			break
	for world: WorldRecord in _state.galaxy.all_worlds():
		var facts: WorldFacts = WorldFactRules.facts_for_id(_state.galaxy, world.id)
		if facts.biohazard == WorldDef.Biohazard.HIGH:
			_state.expedition.world_id = world.id
			_done(&"toxin_resistance")
			assert_int(ExpeditionRules.risk_facts(_state).biohazard).is_equal(
				WorldDef.Biohazard.LOW
			)
			return
