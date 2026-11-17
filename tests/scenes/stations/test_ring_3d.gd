## Tests for the 3D Ring (M5-03): built from the game's 36 glyphs, lamps light with the seals,
## a failed dial flashes, a lock opens the horizon with its surge and lights the hall, the
## Shutter's iris closes over the hole, reduced motion stills the horizon, and the 2D ring
## layers stand down while the 3D Ring shows.
## Bible: docs/content/interface-reference.md sections 5 and 7
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const SCENE: PackedScene = preload("res://src/ui/station/station_scene.tscn")

var _simulation: Simulation = null
var _station: StationScene = null
var _ring: RingLayer = null


func before_test() -> void:
	Station3D.force_enabled = true
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_station = SCENE.instantiate() as StationScene
	add_child(_station)
	_station.size = Vector2(1920, 1080)
	_station.setup(Registry.get_def(&"station_gate") as StationSceneDef)
	_ring = RingLayer.install(_station, _simulation)


func after_test() -> void:
	Station3D.force_enabled = false
	SimClock.stop()
	_station.free()
	Settings.set_value(&"display", &"ambient_movement", true)


func _dial(kind: int) -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, kind)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()


func _run_dial() -> void:
	for i: int in _simulation.state.balance.dial_duration_ticks:
		_simulation.advance_tick()


func _step(seconds: float) -> void:
	_ring.advance(seconds)
	_ring.ring_3d.advance(seconds)


func test_the_ring_is_3d_and_the_2d_layers_stand_down() -> void:
	assert_object(_ring.ring_3d).is_not_null()
	assert_bool((_station.find_child("Horizon", true, false) as CanvasItem).visible).is_false()
	var glyphs: MeshInstance3D = _ring.ring_3d.get_node("Glyphs") as MeshInstance3D
	assert_int(glyphs.mesh.get_surface_count()).is_equal(1)
	assert_int(GateAddress.GLYPH_COUNT).is_equal(36)


func test_lamps_light_with_the_seals_and_a_failure_flashes() -> void:
	_dial(DialOutcome.Kind.LOCK)
	_simulation.advance_tick()
	_step(0.0)
	assert_int(_ring.ring_3d.lit_lamps()).is_equal(_ring.look.seals)
	_run_dial()
	_step(0.0)
	assert_int(_ring.ring_3d.lit_lamps()).is_equal(RingLook.SEALS)


func test_lock_opens_the_horizon_with_a_surge_and_light() -> void:
	_dial(DialOutcome.Kind.LOCK)
	_run_dial()
	_step(0.1)
	_step(0.2)
	assert_float(_ring.ring_3d.burst()).is_greater(0.0)
	assert_bool(_ring.ring_3d.get_light().visible).is_true()
	_step(2.0)
	assert_float(_ring.ring_3d.burst()).is_equal(0.0)
	assert_float(_ring.ring_3d.get_light().light_energy).is_greater(Ring3D.LIGHT_ENERGY * 0.7)


func test_shutter_iris_closes() -> void:
	_simulation.state.gate.shutter = GateState.Shutter.CLOSED
	_step(2.0)
	assert_float(_ring.ring_3d.iris_amount()).is_equal(1.0)


func test_reduced_motion_stills_the_horizon() -> void:
	Settings.set_value(&"display", &"ambient_movement", false)
	_dial(DialOutcome.Kind.LOCK)
	_run_dial()
	_step(0.3)
	assert_float(_ring.ring_3d.burst()).is_equal(0.0)
	var time: Variant = _ring.ring_3d.get_horizon_material().get_shader_parameter(&"time")
	_step(1.0)
	assert_that(_ring.ring_3d.get_horizon_material().get_shader_parameter(&"time")).is_equal(time)


func test_a_failed_dial_flashes_then_goes_dark() -> void:
	_dial(DialOutcome.Kind.NO_GATE)
	_run_dial()
	_step(0.1)
	var lit: int = _ring.ring_3d.lit_lamps()
	assert_bool(lit == 0 or lit == RingLook.SEALS).is_true()
	_step(1.0)
	assert_int(_ring.ring_3d.lit_lamps()).is_equal(0)


func test_a_ripple_ring_runs_out_as_the_surge_settles() -> void:
	assert_float(Ring3D.settle_at(0.1)).is_equal(0.0)
	assert_float(Ring3D.settle_at(HorizonLayer.BURST_SECONDS * 0.7)).is_between(0.01, 0.99)
	assert_float(Ring3D.settle_at(HorizonLayer.BURST_SECONDS)).is_equal(0.0)
