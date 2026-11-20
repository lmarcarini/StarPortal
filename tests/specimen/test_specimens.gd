## M7-03: specimens of alien life come home from worlds with life (a team, the canister after
## Sample canister, the MOTH's sampler after MOTH Mk II), are held with their world, kind and
## age, spoil after SpecimenRules.SPOIL_DAYS unless a Bio Lab cold store runs, and are spent
## by projects that cost them (refused with a reason when missing).
## Bible: docs/content/research-and-progression.md sections 3, 9 and 10
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _state: GameState


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()
	_state.galaxy = ProbeFixture.galaxy()


## A world of [param state]'s galaxy with life of [param kind] (&"" for a dead one).
func _world(kind: StringName) -> StringName:
	for world: WorldRecord in _state.galaxy.all_worlds():
		if SpecimenRules.kind_of(_state, world.id) == kind:
			return world.id
	return &""


func test_worlds_with_life_give_specimens_dead_ones_none() -> void:
	var dead: StringName = _world(&"")
	var alive: StringName = _world(&"plants")
	assert_bool(alive.is_empty()).is_false()
	assert_int(SpecimenRules.add(_state, dead)).is_equal(-1)
	assert_int(SpecimenRules.add(_state, alive)).is_equal(0)
	var record: SpecimenRecord = _state.artefacts.specimens[0]
	assert_str(String(record.world_id)).is_equal(String(alive))
	assert_str(String(record.kind)).is_equal("plants")
	assert_array(StoryFixture.event_names(_state)).contains([&"specimen_arrived"])
	assert_str(SpecimenText.line(_state, record)).ends_with("spoils in 10 d")


func test_spoil_after_ten_days_unless_kept_cold() -> void:
	SpecimenRules.add(_state, _world(&"plants"))
	_state.clock.tick += (SpecimenRules.SPOIL_DAYS - 1) * TimeMath.TICKS_PER_DAY
	assert_int(SpecimenRules.spoil(_state)).is_equal(0)
	_state.clock.tick += TimeMath.TICKS_PER_DAY
	var lab: RoomState = _state.base.add_room(SpecimenRules.BIO_LAB, 1, Vector2i(24, 11))
	var store := InstallationState.new()
	store.def = SpecimenRules.COLD_STORE
	lab.installations.append(store)
	assert_bool(SpecimenRules.has_cold_store(_state)).is_true()
	assert_int(SpecimenRules.spoil(_state)).is_equal(0)
	lab.installations.clear()
	assert_int(SpecimenRules.spoil(_state)).is_equal(1)
	assert_array(_state.artefacts.specimens).is_empty()
	assert_array(StoryFixture.event_names(_state)).contains([&"specimen_spoiled"])


func test_projects_spend_specimens_or_refuse() -> void:
	var def: ResearchDef = ResearchRules.visible_projects(_state, &"science")[0]
	def.specimen_count = 1
	var refused: CommandResult = ResearchRules.can_start(_state, def.id)
	assert_str(String(refused.error_code)).is_equal("needs_specimens")
	SpecimenRules.add(_state, _world(&"plants"))
	(
		assert_bool(ConstructionFixture.run(_state, StartResearchCommand.create(def.id)).is_ok)
		. is_true()
	)
	assert_int(ResearchMaterials.specimens_held(_state)).is_equal(0)
	def.specimen_count = 0


func test_canister_and_sampler_bring_specimens_once_researched() -> void:
	var world: StringName = _world(&"animals")
	_state.flags[SpecimenRules.CANISTER_FLAG] = true
	_state.probes.canister_world_id = world
	_state.probes.canister_ticks_left = 1
	_state.gate.connected_world_id = world
	_state.gate.mode = GateState.RingMode.LOCKED
	ProbeSystem.new().tick(_state)
	assert_int(_state.artefacts.specimens.size()).is_equal(1)
	_state.flags.erase(SpecimenRules.CANISTER_FLAG)
	_state.probes.canister_world_id = world
	_state.probes.canister_ticks_left = 1
	ProbeSystem.new().tick(_state)
	assert_int(_state.artefacts.specimens.size()).is_equal(1)


func test_saved_and_validated() -> void:
	SpecimenRules.add(_state, _world(&"animals"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.artefacts.to_dict()))
	assert_array(ArtefactsState.validate_dict(data)).is_empty()
	assert_dict(ArtefactsState.from_dict(data).to_dict()).is_equal(_state.artefacts.to_dict())
	data["specimens"][0]["kind"] = "rocks"
	assert_array(ArtefactsState.validate_dict(data)).is_not_empty()


func test_debrief_counts_specimens() -> void:
	var d: DebriefRules.Debrief = DebriefRules.of_return(
		_state, _world(&"plants"), {"specimens": 1, "team": []}
	)
	assert_int(d.specimens).is_equal(1)
