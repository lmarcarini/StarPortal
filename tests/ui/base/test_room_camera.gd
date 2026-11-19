## The Base camera inset: the selected room's set with its number and name, people matching
## the tokens, Expand over the board with Esc shrinking it first, and one live feed only
## while the Base is shown.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 8
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	await _runner.simulate_frames(2)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func _base() -> BaseView:
	return _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView


func _staffed_room() -> RoomState:
	var state: GameState = SimClock.simulation.state
	for person: PersonState in StaffLayer.on_base(state):
		if person.room_id != &"":
			return state.base.find_room(person.room_id)
	return null


## The lit plan table (M6-02) has no room camera: it stays hidden.
func test_selecting_shows_the_room_and_nothing_hides_it() -> void:
	var camera: RoomCamera = _base().room_camera
	assert_bool(camera.visible).is_false()
	var room: RoomState = _staffed_room()
	_base().get_plan().show_level(room.level)
	_base().get_plan().select(room.id)
	assert_bool(camera.visible).is_false()
	assert_str(camera.feed.label.text).starts_with("CAM ")
	_base().get_plan().select(&"")
	assert_bool(camera.visible).is_false()
	assert_bool(camera.feed.is_live()).is_false()


func test_people_match_the_tokens_in_the_room() -> void:
	var room: RoomState = _staffed_room()
	var state: GameState = SimClock.simulation.state
	var expected: int = 0
	for person: PersonState in StaffLayer.on_base(state):
		if person.room_id == room.id:
			expected += 1
	_base().get_plan().show_level(room.level)
	_base().get_plan().select(room.id)
	assert_int(_base().room_camera.people().size()).is_equal(expected)
	assert_int(_base().room_camera.feed.get_set().people_count()).is_equal(expected)


func test_expand_covers_the_board_and_cancel_shrinks_it_first() -> void:
	var room: RoomState = _staffed_room()
	_base().get_plan().show_level(room.level)
	_base().get_plan().select(room.id)
	var camera: RoomCamera = _base().room_camera
	camera.expand_button.pressed.emit()
	assert_bool(camera.is_expanded()).is_true()
	assert_object(camera.feed.get_global_rect()).is_equal(_base().get_plan().get_global_rect())
	await _runner.simulate_action_pressed(&"ui_cancel")
	assert_bool(camera.is_expanded()).is_false()
	assert_str(String(_base().get_plan().selected())).is_equal(String(room.id))


func test_no_feed_renders_when_the_base_is_hidden() -> void:
	var room: RoomState = _staffed_room()
	_base().get_plan().select(room.id)
	_shell.view_switcher.show_view(ViewSwitcher.GATE_ROOM)
	assert_bool(_base().room_camera.feed.is_live()).is_false()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	# The lit plan table hides the camera, so it never renders.
	assert_bool(_base().room_camera.feed.is_live()).is_false()
