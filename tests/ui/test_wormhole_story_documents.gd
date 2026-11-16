## Story documents over the real data/ content: each story lock of the M1.5 flow delivers
## nothing by itself, and its pole camera's horizon record delivers exactly the puzzle's
## documents; a second lock of a story world delivers none.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const SEED: int = 20_261_024

var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()


func after_test() -> void:
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
	player.extend_pole_camera()
	return player.state().archive.received.slice(held)


func test_each_story_lock_delivers_its_documents() -> void:
	var player: M15Player = _new_player()
	for index: int in M15Player.PUZZLES.size():
		var arrived: Array[StringName] = _lock(player, index)
		var delivers: Array = M15Player.PUZZLES[index]["delivers"]
		assert_array(arrived).contains_exactly_in_any_order(delivers)
		assert_bool(player.close_wormhole()).is_true()
	assert_array(_lock(player, 0)).is_empty()
