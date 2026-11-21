## The Security sub-tab (M4c-12): hidden until a post or a door exists; squad rows; pick a
## squad, then Enter on the plan orders Move to (also paused); Hold and Fall back; a refused
## order shows its reason; door rows toggle; 1 to 9 pick squads.
## Bible: docs/content/m4c-incursions.md section 7
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null
var _post: RoomState = null


func before_test() -> void:
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(1, defs.balance), defs).value
	UnlockFixture.defence_plans(_simulation.state)
	SimClock.start(_simulation)
	SimClock.pause()
	_root = Control.new()
	_root.size = Vector2(1280, 640)
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	scene_runner(_root)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_root):
		_root.free()


func _add_squad() -> void:
	var state: GameState = _simulation.state
	for x: int in range(2, state.base.grid_size.x - 2):
		var command := PlaceRoomCommand.create(
			SquadRules.POST_DEF, 1, Vector2i(x, StartingBase.SPINE_ROW + 1)
		)
		if command.validate(state).is_ok:
			command.apply(state)
			_post = state.base.rooms[state.base.rooms.size() - 1]
			_post.build_ticks_left = 0
			break
	var person := PersonState.new()
	person.id = &"soldier_a"
	person.name = "A"
	person.role = SquadRules.SOLDIER
	person.room_id = _post.id
	state.staff.people.append(person)
	SquadRules.sync(state)


func test_hidden_until_a_post_exists_then_orders_by_keyboard() -> void:
	var tabs: BaseSubTabs = _view.get_sub_tabs()
	assert_bool(tabs.is_tab_hidden(BaseSubTabs.TABS.find(BaseSubTabs.SECURITY))).is_true()
	_add_squad()
	tabs.show_tab(BaseSubTabs.SECURITY)
	var strip: SecuritySubTab = _root.find_child("SecuritySubTab", true, false) as SecuritySubTab
	assert_bool(strip.visible).is_true()
	strip.pick(_post.id)
	var plan: BasePlan = _view.get_plan()
	plan.cursor = Vector2i(3, StartingBase.SPINE_ROW)
	plan.select_at_cursor()
	var squad: SquadState = _simulation.state.security.squad_of(_post.id)
	assert_int(squad.order).is_equal(SquadState.Order.MOVE)
	assert_int(squad.target.x).is_equal(3)
	strip.hold_button.pressed.emit()
	assert_int(squad.order).is_equal(SquadState.Order.HOLD)
	plan.cursor = Vector2i(0, 0)
	plan.select_at_cursor()
	assert_str(strip.message.text).is_equal("No open path there")


func test_door_rows_toggle() -> void:
	var state: GameState = _simulation.state
	var door := DoorState.new()
	door.cell = Vector2i(3, StartingBase.SPINE_ROW)
	state.base.doors.append(door)
	_view.get_sub_tabs().show_tab(BaseSubTabs.SECURITY)
	var strip: SecuritySubTab = _root.find_child("SecuritySubTab", true, false) as SecuritySubTab
	strip.show_state(state)
	strip._toggle_door(1, door.cell)
	assert_int(door.mode).is_equal(DoorState.Mode.SEALED)
