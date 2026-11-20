## M7-02: the research buildings (Personnel Office, Xenotech Lab, Bio Lab, with the Lab and the
## Workshop) and the Ready Room exist as rooms; each research building names its discipline
## and staff field; the BUILD tray shows only rooms whose plan is known.
## Bible: docs/content/research-and-progression.md sections 3, 8 and 9
extends GdUnitTestSuite

const BUILDINGS: Dictionary[StringName, Array] = {
	&"room_workshop": [&"engineering", &"role_engineer"],
	&"room_research_lab": [&"science", &"role_scientist"],
	&"room_personnel_office": [&"office", &"role_analyst"],
	&"room_xenotech_lab": [&"xenotech", &"role_scientist"],
	&"room_bio_lab": [&"xenobiology", &"role_medic"],
}


func _state() -> GameState:
	var state: GameState = ConstructionFixture.state()
	PowerFixture.load_room_defs(state)
	return state


func test_research_buildings_name_discipline_and_field() -> void:
	var state: GameState = _state()
	for def_id: StringName in BUILDINGS:
		var def: RoomDef = state.room_defs[def_id]
		var wanted: Array = BUILDINGS[def_id]
		assert_str(String(def.research_discipline)).is_equal(str(wanted[0]))
		assert_str(String(def.staff_role)).is_equal(str(wanted[1]))
		assert_int(def.staff_slots).is_greater(0)
		assert_array(def.get_content_errors({})).is_empty()
	var ready: RoomDef = state.room_defs[&"room_ready_room"]
	assert_str(String(ready.research_discipline)).is_empty()


func test_each_discipline_has_a_building() -> void:
	var state: GameState = _state()
	for discipline: StringName in ResearchDef.DISCIPLINES:
		var found: bool = false
		for def: RoomDef in state.room_defs.values():
			found = found or def.research_discipline == discipline
		assert_bool(found).override_failure_message(String(discipline)).is_true()


func test_workshop_keeps_its_build_bonus_and_researches() -> void:
	var state: GameState = _state()
	var shop: RoomState = ResearchFixture.workshop(state)
	assert_array(ResearchRules.buildings(state, &"engineering")).contains([shop])
	assert_int(BuildSpeed.bonus_percent(state)).is_greater(0)


func test_palette_shows_only_known_plans() -> void:
	var palette := BuildPalette.new()
	add_child(palette)
	var state: GameState = _state()
	palette.show_rooms(state.room_defs, [&"room_quarters", &"room_workshop"])
	assert_object(palette.get_room_button(&"room_quarters")).is_not_null()
	assert_object(palette.get_room_button(&"room_bio_lab")).is_null()
	assert_object(palette.get_room_button(&"room_research_lab")).is_null()
	palette.show_rooms(state.room_defs, [&"room_bio_lab"])
	assert_object(palette.get_room_button(&"room_bio_lab")).is_not_null()
	palette.free()
