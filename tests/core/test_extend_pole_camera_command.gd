## Tests for ExtendPoleCameraCommand: refused with no_wormhole (idle or dialing), camera_busy
## while the camera is out and already_taken once the world's record is taken; applied, it sends
## the camera out towards the connected world for EXTEND_TICKS ticks; it round-trips through
## the CommandFactory.
## Bible: game-design.md#base-building-and-power (the pole camera, horizon record),
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = DialFixture.state(null, true)
	_simulation = DialFixture.simulation(_state)


func _dial(id: StringName) -> void:
	var address: GateAddress = DialFixture.address_of(_state.galaxy, id)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()


func _validate() -> CommandResult:
	return ExtendPoleCameraCommand.new().validate(_state)


## With the Ring idle or still dialing there is no wormhole to extend through.
func test_no_wormhole_when_idle_or_dialing() -> void:
	assert_str(_validate().error_code).is_equal(&"no_wormhole")
	_dial(DialFixture.OPEN_ID)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_str(_validate().error_code).is_equal(&"no_wormhole")


## Applied on an open wormhole, the camera goes out towards the connected world; a second
## extension is camera_busy.
func test_extends_towards_the_connected_world() -> void:
	_dial(DialFixture.OPEN_ID)
	_simulation.advance_tick()
	_simulation.advance_tick()
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_bool(_validate().is_ok).is_true()
	assert_bool(_simulation.submit(ExtendPoleCameraCommand.new()).is_ok).is_true()
	assert_str(String(_state.worlds.pole_camera_world_id)).is_equal(String(DialFixture.OPEN_ID))
	assert_int(_state.worlds.pole_camera_ticks_left).is_equal(5)
	assert_int(ExtendPoleCameraCommand.EXTEND_TICKS).is_equal(5)
	assert_str(_validate().error_code).is_equal(&"camera_busy")


## A world whose record was taken refuses the camera with already_taken.
func test_already_taken() -> void:
	_dial(DialFixture.OPEN_ID)
	_simulation.advance_tick()
	_simulation.advance_tick()
	_state.worlds.horizon_records[DialFixture.OPEN_ID] = true
	var result: CommandResult = _validate()
	assert_str(result.error_code).is_equal(&"already_taken")


## The command saves as its type and rebuilds through the CommandFactory.
func test_round_trip() -> void:
	var data: Dictionary = ExtendPoleCameraCommand.new().to_dict()
	assert_dict(data).is_equal({"type": "extend_pole_camera"})
	var rebuilt: Result = CommandFactory.from_dict(data)
	assert_bool(rebuilt.is_ok).is_true()
	assert_bool(rebuilt.value is ExtendPoleCameraCommand).is_true()
