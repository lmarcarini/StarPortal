## M6 flow: the Base console end to end in the running shell. BUILD places a room through
## the palette's ghost; DIG under the level keys digs level 2; POWER's breaker switches a
## room off; STAFF assigns a person by dropping their face tile on a room; SECURITY picks a
## squad and orders it to a room; the pause menu's switches and the save list work.
## Bible: docs/content/interface-reference.md section 8
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const SURVEY: StringName = &"excavation_survey"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _saves: String = ""
var _post: StringName = &""


func before_test() -> void:
	_saves = SaveService.saves_dir
	SaveService.saves_dir = "user://test_m6_flow_%d" % Time.get_ticks_usec()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12345
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	await _runner.simulate_frames(2)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _saves


func _base() -> BaseView:
	return _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView


func _state() -> GameState:
	return SimClock.simulation.state


func test_build_a_room_through_the_palette_ghost() -> void:
	var build: BaseBuild = _base().get_build()
	var before: int = _state().base.rooms.size()
	var cell: Vector2i = _free_cell(build, &"room_quarters")
	assert_bool(cell.x >= 0).is_true()
	build.get_ghost().confirm()
	assert_int(_state().base.rooms.size()).is_equal(before + 1)


func test_dig_level_two_from_the_level_keys() -> void:
	StaffChanges.auto_assign(_state(), PowerFixture.lab(_state()))
	ResearchFixture.workshop(SimClock.simulation.state)
	var result: CommandResult = SimClock.simulation.submit(StartResearchCommand.create(SURVEY))
	assert_bool(result.is_ok).is_true()
	while _state().research.is_running():
		SimClock.step_ticks(60)
	await _runner.await_input_processed()
	var dig: DigButton = _base().get_palette().get_dig_button()
	assert_bool(dig.press_now()).is_true()
	assert_int(_state().base.digging_level()).is_equal(2)
	while _state().base.digging_level() != 0:
		SimClock.step_ticks(120)
	await _runner.await_input_processed()
	var tabs: LevelTabs = _base().find_child("LevelTabs", true, false) as LevelTabs
	tabs.get_key(2).pressed.emit()
	assert_int(_base().get_plan().level).is_equal(2)


func test_power_breaker_switches_a_room() -> void:
	var lab: RoomState = PowerFixture.lab(_state())
	_base().get_sub_tabs().show_tab(BaseSubTabs.ENERGY)
	await _runner.simulate_frames(2)
	var tray: PowerTray = _base().find_child("PowerTray", true, false) as PowerTray
	assert_bool(tray.visible).is_true()
	tray.show_state(_state())
	var found: Breaker = null
	for breaker: Breaker in tray.get_breakers():
		if breaker.room_id == lab.id:
			found = breaker
	assert_object(found).is_not_null()
	var was: bool = lab.powered_on
	found.pressed.emit()
	assert_bool(lab.powered_on).is_equal(not was)


func test_staff_drag_lights_the_room_and_assigns_on_drop() -> void:
	var pair: Array[StringName] = _free_pair()
	assert_array(pair).is_not_empty()
	SimClock.simulation.submit(UnassignStaffCommand.create(pair[0]))
	_base().get_sub_tabs().show_tab(BaseSubTabs.STAFF)
	await _runner.simulate_frames(2)
	var tile: StaffFaceKey = _face_of(pair[0])
	assert_object(tile).is_not_null()
	tile.drag_started.emit(pair[0])
	var plan: BasePlan = _base().get_plan()
	assert_bool(plan.staff_layer.assign.allows(pair[1])).is_true()
	plan.show_level(_state().base.find_room(pair[1]).level)
	plan._drop_data(_screen_of(pair[1]), {"person": pair[0]})
	assert_str(String(_state().staff.find_person(pair[0]).room_id)).is_equal(String(pair[1]))
	assert_bool(plan.staff_layer.assign.is_active()).is_false()


func test_security_orders_a_picked_squad_to_a_room() -> void:
	_arm()
	_base().get_sub_tabs().show_tab(BaseSubTabs.SECURITY)
	await _runner.simulate_frames(2)
	var tab: SecuritySubTab = _base().find_child("SecuritySubTab", true, false) as SecuritySubTab
	tab.pick(_post)
	assert_str(String(_base().get_plan().security_layer.preview_squad)).is_equal(String(_post))
	var lab: RoomState = PowerFixture.lab(_state())
	var plan: BasePlan = _base().get_plan()
	plan.show_level(1)
	plan.cursor = lab.origin
	plan.select_at_cursor()
	var squad: SquadState = _state().security.squad_of(_post)
	assert_int(squad.order).is_equal(SquadState.Order.MOVE)
	assert_int(squad.target.x).is_equal(lab.origin.x)


func test_pause_menu_switches_and_save_list() -> void:
	var menu: PauseMenu = _shell.pause_menu
	menu.open()
	var was: bool = Settings.get_bool(&"gameplay", &"auto_open_team_report")
	menu.report_toggle.button_pressed = not was
	assert_bool(Settings.get_bool(&"gameplay", &"auto_open_team_report")).is_equal(not was)
	menu.report_toggle.button_pressed = was
	menu.save_button.pressed.emit()
	menu.slots.name_field.text = "flow_m6"
	menu.slots.save_new()
	await _runner.await_input_processed()
	menu.load_button.pressed.emit()
	var rows: Array[Button] = menu.slots.rows()
	assert_array(rows).is_not_empty()
	assert_object(rows[0]).is_instanceof(SlotRow)
	menu.back()
	menu.close()
	assert_bool(menu.is_open()).is_false()


func _free_cell(build: BaseBuild, def_id: StringName) -> Vector2i:
	var grid: Vector2i = _state().base.grid_size
	for y: int in range(1, grid.y - 1):
		for x: int in range(1, grid.x - 1):
			build.place_at(def_id, Vector2i(x, y))
			if build.get_ghost().reason().is_empty():
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _free_pair() -> Array[StringName]:
	var state: GameState = _state()
	for person: PersonState in StaffLayer.on_base(state):
		var mode := AssignMode.new()
		mode.start(state, person.id)
		if not mode.allowed_rooms().is_empty():
			return [person.id, mode.allowed_rooms()[0]] as Array[StringName]
	return [] as Array[StringName]


func _face_of(person_id: StringName) -> StaffFaceKey:
	for node: Node in _base().find_children("*", "StaffFaceKey", true, false):
		var tile: StaffFaceKey = node as StaffFaceKey
		if tile.person_id == person_id:
			return tile
	return null


func _screen_of(room_id: StringName) -> Vector2:
	var room: RoomState = _state().base.find_room(room_id)
	var def: RoomDef = _state().room_defs.get(room.def_id)
	var cells: Rect2i = BaseRules.footprint(room, def)
	var plan: BasePlan = _base().get_plan()
	var centre: Vector2 = Vector2(cells.position) + Vector2(cells.size) * 0.5
	return centre * BasePlanPainter.CELL * plan.view.scale() + plan.view.offset


# A security post built through the ghost and finished, manned by two soldiers (test setup:
# the seed's people take the soldier role when it has none).
func _arm() -> void:
	var state: GameState = _state()
	UnlockFixture.defence_plans(state)
	_base().get_build().refresh()
	var build: BaseBuild = _base().get_build()
	var cell: Vector2i = _free_cell(build, &"room_security_post")
	build.get_ghost().confirm()
	build.get_ghost().stop()
	var post: RoomState = null
	for room: RoomState in state.base.rooms:
		if room.def_id == &"room_security_post" and room.origin == cell:
			post = room
	post.build_ticks_left = 0
	post.powered_on = true
	var armed: int = 0
	for person: PersonState in StaffLayer.on_base(state):
		if armed < 2:
			person.role = SquadRules.SOLDIER
			person.room_id = post.id
			person.lent = false
			armed += 1
	SquadRules.sync(state)
	_post = post.id
