## Staff tokens on the base plan: one per person on base, in their room or in the tray,
## on the right level, and Show on plan from Personnel.
## Bible: docs/content/interface-pass.md section 5 (Staff tokens)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 3
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	await _runner.simulate_frames(2)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func _plan() -> BasePlan:
	var base: BaseView = _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	return base.get_plan()


func test_one_token_per_person_on_base_inside_their_room() -> void:
	var state: GameState = SimClock.simulation.state
	var layer: StaffLayer = _plan().staff_layer
	assert_int(layer.tokens().size()).is_equal(StaffLayer.on_base(state).size())
	for person: PersonState in StaffLayer.on_base(state):
		var token: StaffToken = layer.token_for(person.id)
		var room: RoomState = state.base.find_room(person.room_id)
		if room == null:
			continue
		var def: RoomDef = state.room_defs.get(room.def_id)
		var cells: Rect2i = BaseRules.footprint(room, def)
		var area := Rect2(Vector2(cells.position) * 24.0, Vector2(cells.size) * 24.0)
		assert_bool(area.has_point(token.position)).is_true()
		assert_int(token.level).is_equal(room.level)


func test_unassigned_go_to_the_tray_and_arrivals_are_hidden() -> void:
	var state: GameState = SimClock.simulation.state
	var person: PersonState = state.staff.people[0]
	person.room_id = &""
	EventBus.staff_changed.emit(&"unassigned", &"", 1)
	assert_int(_plan().tray.buttons().size()).is_greater_equal(1)
	person.arrives_tick = state.clock.tick + 100
	EventBus.staff_changed.emit(&"test", &"", 0)
	assert_object(_plan().staff_layer.token_for(person.id)).is_null()


func test_token_at_finds_the_token_under_a_point_and_selection_follows() -> void:
	var layer: StaffLayer = _plan().staff_layer
	var token: StaffToken = layer.tokens()[0]
	_plan().show_level(token.level)
	var screen: Vector2 = token.position * _plan().view.scale() + _plan().view.offset
	assert_str(String(layer.token_at(screen))).is_equal(String(token.person_id))
	layer.focus_person(token.person_id)
	assert_str(String(layer.selected())).is_equal(String(token.person_id))


func test_room_spots_fit_inside_and_clear_the_label() -> void:
	for count: int in [1, 2, 3, 4, 6]:
		var spots: Array[Vector2] = RoomSpots.for_room(null, Vector2i(4, 3), count)
		assert_int(spots.size()).is_equal(count)
		for spot: Vector2 in spots:
			assert_float(spot.y).is_greater_equal(RoomSpots.LABEL_STRIP)
			assert_bool(Rect2(0, 0, 1, 1).has_point(spot)).is_true()


func test_role_shapes_differ() -> void:
	var seen: Array[StringName] = []
	for role: StringName in [
		&"role_scientist", &"role_engineer", &"role_analyst", &"role_soldier", &"role_medic"
	]:
		assert_bool(seen.has(StaffToken.shape_of(role))).is_false()
		seen.append(StaffToken.shape_of(role))


func test_show_on_plan_opens_base_with_the_token_selected() -> void:
	var state: GameState = SimClock.simulation.state
	var person: PersonState = StaffLayer.on_base(state)[0]
	_shell.view_switcher.show_view(ViewSwitcher.PERSONNEL)
	var personnel: PersonnelView = (
		_shell.view_switcher.get_view(ViewSwitcher.PERSONNEL) as PersonnelView
	)
	personnel.show_on_plan.emit(person.id)
	await _runner.simulate_frames(1)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("base")
	assert_str(String(_plan().staff_layer.selected())).is_equal(String(person.id))
