## Tests for the send rail: it shows on a lock and goes on a close, each key submits its
## command (operating the gate first), refusals become hover reasons, an answered incoming
## wormhole shows only HAIL, STAND BY stands by, and it keeps clear of the Ring and ramp.
## Bible: docs/content/interface-rethink.md section 4 (Gate, With a wormhole open)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	DialFixture.give_moth_rack(_simulation.state)
	SimClock.start(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	_holder.free()


func _lock() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	_simulation.submit(DialCommand.create(address))
	for i: int in _simulation.state.balance.dial_duration_ticks + 1:
		_simulation.advance_tick()
	_view.get_rail().refresh()


func test_rail_follows_the_wormhole() -> void:
	assert_bool(_view.get_rail().visible).is_false()
	_lock()
	assert_bool(_view.get_rail().visible).is_true()
	_simulation.submit(CloseWormholeCommand.new())
	_view.get_rail().refresh()
	assert_bool(_view.get_rail().visible).is_false()


func test_camera_key_operates_and_extends() -> void:
	_lock()
	_view.get_rail().press(&"camera")
	assert_bool(_simulation.state.gate.operating).is_true()
	assert_bool(_simulation.state.worlds.is_pole_camera_out()).is_true()
	assert_int(_view.get_rail().get_key(&"camera").get_state()).is_equal(IconKey.KeyState.ACTIVE)


func test_moth_key_badge_and_launch() -> void:
	_lock()
	var key: IconKey = _view.get_rail().get_key(&"moth")
	assert_str(key.badge_text).is_equal(str(_simulation.state.probes.rack))
	_view.get_rail().press(&"moth")
	assert_bool(_simulation.state.probes.is_moth_out()).is_true()


func test_team_unavailable_with_reason() -> void:
	_lock()
	var key: IconKey = _view.get_rail().get_key(&"team")
	assert_int(key.get_state()).is_equal(IconKey.KeyState.UNAVAILABLE)
	var card: HoverCard = key.find_child("HoverCard", false, false) as HoverCard
	assert_str(card.get_text()).is_not_empty()


func test_incoming_shows_only_hail() -> void:
	_simulation.state.gate.mode = GateState.RingMode.LOCKED
	_simulation.state.gate.incoming_faction = &"faction_x"
	for look: SendRailRules.KeyLook in SendRailRules.looks(_simulation.state):
		if look.id != &"hail":
			assert_bool(look.shown).is_false()


func test_stand_by() -> void:
	_lock()
	_view.get_rail().press(&"camera")
	_view.get_rail().stand_by()
	assert_bool(_simulation.state.gate.operating).is_false()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.LOCKED)


func test_rail_clear_of_ring_and_ramp() -> void:
	_lock()
	_view._layout()
	var rail: Rect2 = _view.get_rail().get_rect()
	var station: StationScene = _view.get_station()
	var ring: Vector2 = station.anchor(&"ring_outer")
	assert_float(rail.position.distance_to(ring)).is_greater(station.radius(&"ring_outer"))
	var ramp: PackedVector2Array = station.shape(&"ramp")
	assert_float(rail.position.x).is_greater(ramp[0].x)
