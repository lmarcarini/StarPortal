## Alarm state and the plan (M4c-11): sight follows power and squads; the strip shows the
## countdown, the levels and the Overrun countdown; the alert opens Base, Security; the
## security layer remembers sightings and marks the objective; ambient movement stops.
## Bible: docs/content/m4c-incursions.md section 7
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = GameState.new_game(9, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 8
	_state.unit_defs[unit.id] = unit
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [unit.id]
	def.group_counts = [3]
	def.objective = &"sabotage"
	_state.incursion_defs[def.id] = def


func _room(def_id: StringName) -> RoomState:
	for room: RoomState in _state.base.rooms:
		if room.def_id == def_id:
			return room
	return null


func test_sight_follows_power() -> void:
	IncursionRules.start(_state, &"incursion_test")
	IncursionRules.breach(_state)
	var group: IntruderGroup = _state.incursion.groups[0]
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	group.move_to(Vector3i(plant.origin.x, plant.origin.y, plant.level))
	assert_bool(SightRules.visible(_state, group)).is_true()
	plant.damaged = true
	assert_bool(SightRules.visible(_state, group)).is_false()


func test_strip_text_and_alert() -> void:
	assert_str(AlarmText.strip(_state)).is_empty()
	IncursionRules.start(_state, &"incursion_test")
	assert_str(AlarmText.strip(_state)).is_equal("UNSCHEDULED INCOMING — 30")
	IncursionRules.breach(_state)
	assert_str(AlarmText.strip(_state)).contains("INTRUDERS ON LEVEL 1")
	_state.outcome.overrun_ticks = 5
	assert_str(AlarmText.strip(_state)).contains("CONTROL ROOM FALLS IN 25")
	var found: bool = false
	for entry: AlertEntry in AlertRules.current(_state):
		if entry.kind == &"incursion":
			found = entry.view_id == ViewSwitcher.BASE and entry.sub_tab == &"security"
	assert_bool(found).is_true()


func test_layer_remembers_sightings_and_marks_the_objective() -> void:
	IncursionRules.start(_state, &"incursion_test")
	IncursionRules.breach(_state)
	var layer := SecurityLayer.new()
	layer.update_from(_state)
	assert_bool(layer.last_seen.has(0)).is_true()
	assert_array(layer.targets).contains([_room(ObjectiveRules.POWER_PLANT_DEF).id])
	layer.free()
