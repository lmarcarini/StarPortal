## Tests for the Ring's live layers on the Gate plate: seals light as they lock, a failed
## dial flashes, a lock grows the horizon clipped to the hole and lights the hall, a close
## shrinks it, the Shutter closes over the hole, and reduced motion stills the shimmer.
## Bible: docs/content/interface-rethink.md sections 4 and 7
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const SCENE: PackedScene = preload("res://src/ui/station/station_scene.tscn")

var _simulation: Simulation = null
var _station: StationScene = null
var _ring: RingLayer = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_station = SCENE.instantiate() as StationScene
	add_child(_station)
	_station.size = Vector2(1920, 1080)
	_station.setup(Registry.get_def(&"station_gate") as StationSceneDef)
	_ring = RingLayer.install(_station, _simulation)


func after_test() -> void:
	SimClock.stop()
	_station.free()
	Settings.set_value(&"display", &"ambient_movement", true)


func _dial(kind: int) -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, kind)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()


func _run_dial() -> void:
	for i: int in _simulation.state.balance.dial_duration_ticks:
		_simulation.advance_tick()


func test_seals_light_one_by_one() -> void:
	assert_int(RingLook.seals_at(0, 8)).is_less(RingLook.seals_at(4, 8))
	assert_int(RingLook.seals_at(100, 8)).is_equal(7)
	_dial(DialOutcome.Kind.LOCK)
	_ring.advance(0.0)
	assert_int(_ring.look.phase).is_equal(RingLook.Phase.DIALING)


func test_lock_opens_horizon_and_light() -> void:
	_dial(DialOutcome.Kind.LOCK)
	_run_dial()
	_ring.advance(0.5)
	assert_float(_ring.open_amount).is_equal_approx(0.5, 0.01)
	_ring.advance(0.6)
	assert_float(_ring.open_amount).is_equal(1.0)
	assert_int(_ring.look.seals).is_equal(RingLook.SEALS)
	var light: GateLightLayer = _station.find_child("GateLight", true, false) as GateLightLayer
	assert_float(light.strength()).is_equal_approx(1.0, GateLightLayer.FLICKER + 0.01)
	var horizon: HorizonLayer = _station.find_child("Horizon", true, false) as HorizonLayer
	horizon._process(0.0)
	var radius: float = horizon.get_shader_material().get_shader_parameter(&"radius")
	assert_float(radius).is_equal_approx(_station.radius(&"ring_inner"), 0.01)
	_simulation.submit(CloseWormholeCommand.new())
	_ring.advance(2.0)
	assert_float(_ring.open_amount).is_equal(0.0)


func test_failed_dial_flashes() -> void:
	_dial(DialOutcome.Kind.NO_GATE)
	_run_dial()
	_ring.advance(0.1)
	assert_bool(_ring.is_flashing_failure()).is_true()
	_ring.advance(1.0)
	assert_bool(_ring.is_flashing_failure()).is_false()
	assert_float(_ring.open_amount).is_equal(0.0)


func test_shutter_closes_over_hole() -> void:
	_simulation.state.gate.shutter = GateState.Shutter.CLOSED
	_ring.advance(2.0)
	assert_float(_ring.shutter_amount).is_equal(1.0)


func test_reduced_motion_stills_shimmer() -> void:
	Settings.set_value(&"display", &"ambient_movement", false)
	var before: float = _ring.shimmer
	_ring.advance(1.0)
	assert_float(_ring.shimmer).is_equal(before)


func test_kawoosh_overshoots_then_settles() -> void:
	assert_float(HorizonLayer.burst_at(-1.0)).is_equal(0.0)
	assert_float(HorizonLayer.burst_at(0.25)).is_greater(0.5)
	assert_float(HorizonLayer.burst_at(1.0)).is_less(0.3)
	assert_float(HorizonLayer.burst_at(HorizonLayer.BURST_SECONDS)).is_equal(0.0)


func test_light_flickers_gently_and_stills_without_shimmer() -> void:
	var seen: Array[float] = []
	for step: int in 20:
		seen.append(GateLightLayer.flicker_at(step * 0.37))
	assert_float(seen.max()).is_less_equal(1.0 + GateLightLayer.FLICKER)
	assert_float(seen.min()).is_greater_equal(1.0 - GateLightLayer.FLICKER)
	assert_float(seen.max() - seen.min()).is_greater(0.02)
	assert_float(GateLightLayer.flicker_at(4.0)).is_equal(GateLightLayer.flicker_at(4.0))
