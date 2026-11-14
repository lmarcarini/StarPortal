## Blast doors on the plan (M4c-04): the palette offers one, the ghost places it on a corridor
## cell, and a click or Enter on a built door toggles it while paused; the painter draws it.
## Bible: docs/content/m4c-incursions.md section 4
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null


func before_test() -> void:
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(1, defs.balance), defs).value
	_root = Control.new()
	_root.size = Vector2(1280, 640)
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	scene_runner(_root)
	_view.setup(_simulation)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()


func _free_corridor() -> Vector2i:
	var state: GameState = _simulation.state
	for room: RoomState in state.base.rooms:
		if room.def_id == StartingBase.CORRIDOR_DEF and room.level == 1:
			if DoorRules.can_build(state, 1, room.origin).is_ok:
				return room.origin
	return Vector2i(-1, -1)


func test_place_and_toggle_a_door() -> void:
	var build: BaseBuild = _view.get_build()
	var palette: BuildPalette = build.get_palette()
	assert_object(palette.get_room_button(BuildPalette.DOOR_ID)).is_not_null()
	var cell: Vector2i = _free_corridor()
	build.place_at(BuildPalette.DOOR_ID, cell)
	var ghost: PlacementGhost = build.get_ghost()
	assert_str(String(ghost.def_id)).is_equal(String(BuildPalette.DOOR_ID))
	assert_str(ghost.reason()).is_empty()
	assert_int(ghost.cost_k()).is_equal(50)
	ghost.confirm()
	var door: DoorState = DoorRules.find(_simulation.state.base, 1, cell)
	assert_object(door).is_not_null()
	ghost.stop()
	door.build_ticks_left = 0
	var plan: BasePlan = build.get_plan()
	plan.show_level(1)
	plan.cursor = cell
	plan.select_at_cursor()
	assert_int(door.mode).is_equal(DoorState.Mode.SEALED)
	plan.select_at_cursor()
	assert_int(door.mode).is_equal(DoorState.Mode.OPEN)
	ghost.start(BuildPalette.DOOR_ID, Vector2i(0, 0))
	assert_str(ghost.reason()).is_not_empty()
	ghost.stop()
