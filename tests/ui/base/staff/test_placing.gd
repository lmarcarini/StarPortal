## Allocation by placing: drag a token to a room or the tray, select-then-place with the
## keyboard, refusals with the command's reason, and the Staff sub-tab list and tints.
## Bible: docs/content/interface-pass.md section 5 (Allocation by placing)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 31
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	await _runner.simulate_frames(2)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func _plan() -> BasePlan:
	return (_shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView).get_plan()


## A person and a room on level 1 that can take them, or [] when there is none.
func _pair() -> Array[StringName]:
	var state: GameState = SimClock.simulation.state
	for person: PersonState in StaffLayer.on_base(state):
		var mode := AssignMode.new()
		mode.start(state, person.id)
		for room_id: StringName in mode.allowed_rooms():
			if state.base.find_room(room_id).level == 1:
				return [person.id, room_id] as Array[StringName]
	return [] as Array[StringName]


func _screen_of(room_id: StringName) -> Vector2:
	var state: GameState = SimClock.simulation.state
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = state.room_defs.get(room.def_id)
	var cells: Rect2i = BaseRules.footprint(room, def)
	var centre: Vector2 = (Vector2(cells.position) + Vector2(cells.size) * 0.5) * 24.0
	return centre * _plan().view.scale() + _plan().view.offset


func test_assign_mode_uses_the_command_validation() -> void:
	var pair: Array[StringName] = _pair()
	assert_array(pair).is_not_empty()
	var state: GameState = SimClock.simulation.state
	var mode := AssignMode.new()
	mode.start(state, pair[0])
	for room: RoomState in state.base.rooms:
		var ok: bool = AssignStaffCommand.create(pair[0], room.id).validate(state).is_ok
		assert_bool(mode.allows(room.id)).is_equal(ok)


func test_drag_a_token_onto_a_room_assigns_and_onto_the_tray_unassigns() -> void:
	var pair: Array[StringName] = _pair()
	var person: StringName = pair[0]
	var room_id: StringName = pair[1]
	var plan: BasePlan = _plan()
	plan.show_level(1)
	var token: StaffToken = plan.staff_layer.token_for(person)
	plan.staff_layer.snap()
	var start: Vector2 = token.position * plan.view.scale() + plan.view.offset
	plan.drop_at(start)
	plan.staff_layer.drag.press(person, start)
	assert_bool(plan.staff_layer.drag.move(start + Vector2(20, 0))).is_true()
	plan.staff_layer.assign.start(SimClock.simulation.state, person)
	assert_bool(plan.drop_at(_screen_of(room_id))).is_true()
	var state: GameState = SimClock.simulation.state
	assert_str(String(state.staff.find_person(person).room_id)).is_equal(String(room_id))
	plan.staff_layer.drag.release()
	plan.staff_layer.rebuild(state)
	plan.staff_layer.assign.start(state, person)
	await _runner.simulate_frames(1)
	if plan.tray.visible:
		var tray_point: Vector2 = (
			plan.get_global_transform().affine_inverse() * plan.tray.get_global_rect().get_center()
		)
		plan.drop_at(tray_point)
		assert_str(String(state.staff.find_person(person).room_id)).is_equal("")


func test_refused_drop_says_why_and_select_then_place_works_with_keys() -> void:
	var pair: Array[StringName] = _pair()
	var plan: BasePlan = _plan()
	var messages: Array[String] = []
	plan.placement_message.connect(func(text: String) -> void: messages.append(text))
	plan.staff_layer.assign.start(SimClock.simulation.state, pair[0])
	plan.drop_at(Vector2(-500, -500))
	assert_bool(messages.is_empty()).is_false()
	assert_str(messages.back()).is_not_empty()
	plan.start_placing(pair[0])
	assert_bool(plan.staff_layer.assign.is_active()).is_true()
	await _runner.simulate_action_pressed(&"ui_cancel")
	assert_bool(plan.staff_layer.assign.is_active()).is_false()
	plan.start_placing(pair[0])
	var room: RoomState = SimClock.simulation.state.base.find_room(pair[1])
	plan.cursor = room.origin
	await _runner.simulate_action_pressed(&"ui_accept")
	var person: PersonState = SimClock.simulation.state.staff.find_person(pair[0])
	assert_bool(SimClock.simulation.state.base.find_room(person.room_id) != null).is_true()


func test_staff_sub_tab_lists_everyone_and_tints() -> void:
	var base: BaseView = _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	base.get_sub_tabs().show_tab(BaseSubTabs.STAFF)
	await _runner.simulate_frames(1)
	var tabs: BaseViewTabs = base.find_child("Tabs", true, false) as BaseViewTabs
	assert_bool(tabs.staff_tab.visible).is_true()
	assert_bool(_plan().staff_layer.tint).is_true()
	var count: int = StaffLayer.on_base(SimClock.simulation.state).size()
	assert_int(tabs.staff_tab.rows().size()).is_equal(count)
	base.get_sub_tabs().show_tab(BaseSubTabs.BUILD)
	assert_bool(tabs.staff_tab.visible).is_false()
	assert_bool(_plan().staff_layer.tint).is_false()
