## Tests for InstallCapacitorsCommand: a new game cannot dial until the first capacitor bank
## is installed; the install starts, runs 360 ticks, adds 400 MWh and posts
## capacitors_installed and the pause request once; the rejections; and a save taken
## mid-install keeps the ticks left.
## Bible: gate-and-address-spec.md#the-dial-console, game-design.md#core-loop,
## technical-architecture.md#save-system
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const SEED: int = 20_261_023

var _simulation: Simulation
var _events: Array[StringName] = []
var _pauses: Array[StringName] = []
var _installed: Array[float] = []


func before_test() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build(GameState.new_game(SEED, defs.balance), defs)
	_simulation = built.value
	_events.clear()
	_pauses.clear()
	_installed.clear()
	_simulation.event_posted.connect(_on_event_posted)
	_simulation.pause_requested.connect(_on_pause_requested)


func _on_event_posted(event_name: StringName, args: Array) -> void:
	_events.append(event_name)
	if event_name == &"capacitors_installed":
		var capacity: float = args[0]
		_installed.append(capacity)


func _on_pause_requested(reason: StringName) -> void:
	_pauses.append(reason)


func _power() -> PowerState:
	return _simulation.state.power


func _advance(ticks: int) -> void:
	for index: int in ticks:
		_simulation.advance_tick()


## The address of the first world other than CAIRN.
func _some_address() -> GateAddress:
	var galaxy: GalaxyCatalogue = _simulation.state.galaxy
	var home: WorldRecord = galaxy.home()
	for world: WorldRecord in galaxy.all_worlds():
		if world.id != home.id:
			return galaxy.address_of(world.id, home.origin_glyph)
	return null


## A new game has no capacitors and stores nothing however long it runs, so nothing dials.
func test_new_game_cannot_dial_before_the_install() -> void:
	assert_float(_power().capacity_mwh).is_equal(0.0)
	assert_int(_power().banks_installed).is_equal(0)
	_advance(600)
	assert_float(_power().stored_mwh).is_equal(0.0)
	var result := _simulation.submit(DialCommand.create(_some_address()))
	assert_str(String(result.error_code)).is_equal("insufficient_charge")


## The command applies at once while paused and starts a 360-tick job; after exactly 360
## ticks the capacity is 400 MWh, the event and the pause request came once, and charging
## then follows the power rules.
func test_install_runs_360_ticks_then_adds_the_bank() -> void:
	assert_bool(_simulation.submit(InstallCapacitorsCommand.new()).is_ok).is_true()
	assert_int(_power().install_ticks_left).is_equal(360)
	_advance(359)
	assert_float(_power().capacity_mwh).is_equal(0.0)
	assert_array(_installed).is_empty()
	_advance(1)
	assert_int(_simulation.state.clock.tick).is_equal(360)
	assert_float(_power().capacity_mwh).is_equal(400.0)
	assert_int(_power().banks_installed).is_equal(1)
	assert_int(_power().install_ticks_left).is_equal(0)
	assert_array(_installed).is_equal([400.0])
	assert_array(_pauses).is_equal([&"capacitors_installed"])
	_advance(600)
	assert_array(_installed).has_size(1)
	assert_array(_pauses).has_size(1)
	assert_float(_power().stored_mwh).is_equal_approx(300.5, 1e-9)


## A command submitted while the clock runs waits for the next tick and still takes 360.
func test_install_submitted_while_running_takes_360_ticks() -> void:
	_simulation.state.clock.is_paused = false
	assert_bool(_simulation.submit(InstallCapacitorsCommand.new()).is_ok).is_true()
	assert_int(_power().install_ticks_left).is_equal(0)
	_advance(359)
	assert_float(_power().capacity_mwh).is_equal(0.0)
	_advance(1)
	assert_float(_power().capacity_mwh).is_equal(400.0)


## While an install runs another is refused with install_running; once the one bank slot is
## used, with no_bank_slot. A refused command changes nothing.
func test_rejections() -> void:
	_simulation.submit(InstallCapacitorsCommand.new())
	_advance(10)
	var running := _simulation.submit(InstallCapacitorsCommand.new())
	assert_str(String(running.error_code)).is_equal("install_running")
	assert_int(_power().install_ticks_left).is_equal(350)
	_advance(350)
	var full := _simulation.submit(InstallCapacitorsCommand.new())
	assert_str(String(full.error_code)).is_equal("no_bank_slot")
	assert_int(_power().install_ticks_left).is_equal(0)
	assert_float(_power().capacity_mwh).is_equal(400.0)


## Without a balance there is no bank slot to fill.
func test_no_balance_has_no_slot() -> void:
	var result := InstallCapacitorsCommand.new().validate(GameState.new_game(1))
	assert_str(String(result.error_code)).is_equal("no_bank_slot")


## The command has no arguments and rebuilds from its to_dict().
func test_to_dict_and_back() -> void:
	var data := InstallCapacitorsCommand.new().to_dict()
	assert_dict(data).is_equal({"type": "install_capacitors"})
	var rebuilt: Result = InstallCapacitorsCommand.from_dict(data)
	assert_bool(rebuilt.value is InstallCapacitorsCommand).is_true()


## A save taken mid-install keeps the ticks left, and the loaded game finishes the install on
## the same tick.
func test_save_and_load_mid_install() -> void:
	_simulation.submit(InstallCapacitorsCommand.new())
	_advance(160)
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_install_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	assert_bool(service.save_game(_simulation.state, &"mid_install").is_ok).is_true()
	var result: Result = service.load_game(&"mid_install")
	DirAccess.remove_absolute(service.slot_path(&"mid_install"))
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	assert_int(loaded.power.install_ticks_left).is_equal(200)
	assert_int(loaded.power.banks_installed).is_equal(0)
	var built: Result = GameSetup.build(loaded, GameDefs.from_registry(Registry))
	var resumed: Simulation = built.value
	for index: int in 199:
		resumed.advance_tick()
	assert_float(loaded.power.capacity_mwh).is_equal(0.0)
	resumed.advance_tick()
	assert_float(loaded.power.capacity_mwh).is_equal(400.0)
	assert_int(loaded.clock.tick).is_equal(360)
