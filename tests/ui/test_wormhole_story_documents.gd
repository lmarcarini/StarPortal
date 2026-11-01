## The wormhole screen's new-documents line over the real data/ content: after each story
## lock of the M1.5 flow and its pole camera's horizon record it names exactly the documents the
## record delivered (none before the camera goes out), a second lock of a story world names
## none, and the screen still fits the minimum window with the longest list (the second lock's
## five documents) and the console read, in en and pt_BR.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const SEED: int = 20_261_024

var _holder: Control = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _new_player() -> M15Player:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, defs.balance), defs)
	assert_bool(built.is_ok).is_true()
	var simulation: Simulation = built.value
	var player := M15Player.new(simulation)
	assert_int(player.build_bank()).is_greater(0)
	return player


## Dials puzzle [param index]'s answer, checks nothing arrived with the lock alone, extends the
## pole camera and returns the documents its horizon record delivered.
func _lock(player: M15Player, index: int) -> Array[StringName]:
	var puzzle: Dictionary = M15Player.PUZZLES[index]
	var glyphs: Array = puzzle["glyphs"]
	var target: GateAddress = player.address(glyphs)
	var held: int = player.state().archive.received.size()
	assert_bool(player.wait_for_charge(target)).is_true()
	assert_object(player.dial(target)).is_not_null()
	assert_int(player.state().gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(player.state().archive.received.size()).is_equal(held)
	assert_array(WormholeText.new_documents(player.state())).is_empty()
	player.extend_pole_camera()
	return player.state().archive.received.slice(held)


func test_each_story_lock_names_what_it_delivered() -> void:
	var player: M15Player = _new_player()
	for index: int in M15Player.PUZZLES.size():
		var arrived: Array[StringName] = _lock(player, index)
		var delivers: Array = M15Player.PUZZLES[index]["delivers"]
		assert_array(arrived).contains_exactly_in_any_order(delivers)
		assert_array(WormholeText.new_documents(player.state())).is_equal(arrived)
		assert_bool(player.close_wormhole()).is_true()
		assert_array(WormholeText.new_documents(player.state())).is_empty()
	_lock(player, 0)
	assert_array(WormholeText.new_documents(player.state())).is_empty()


@warning_ignore("unused_parameter")
func test_the_longest_list_fits_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	var player: M15Player = _new_player()
	_lock(player, 0)
	player.close_wormhole()
	assert_int(_lock(player, 1).size()).is_equal(5)
	assert_array(player.read_console()).is_not_empty()
	SimClock.start(player.simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	var view: GateRoomView = Fixture.view_of(_holder)
	view.setup(player.simulation)
	Fixture.open_actions(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: WormholeScreen = view.get_overlays().get_wormhole_screen()
	assert_bool(screen.is_showing_open()).is_true()
	var line: Label = screen.get_node("%NewDocuments") as Label
	assert_bool(line.is_visible_in_tree()).is_true()
	assert_int(line.text.split(", ").size()).is_greater_equal(5)
	assert_bool(screen.get_console().is_read()).is_true()
	var column: Control = screen.get_node("Column") as Control
	var needed: Vector2 = column.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(column.size.x)
	assert_float(needed.y).is_less_equal(column.size.y)
	assert_float((screen.get_node("%Strip") as Control).size.y).is_less_equal(column.size.y / 2.0)
