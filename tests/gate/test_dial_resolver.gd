## Tests for DialResolver on the small dial fixture galaxy: one test per outcome, the wrong
## origin, the wrong coordinates, CAIRN's own address and worlds dialed with another Ring's
## origin; then every world of a generated galaxy against its own status.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const GalaxyFixture := preload("res://tests/gate/galaxy_fixture.gd")

var _galaxy: GalaxyCatalogue
var _home_origin: int


func before() -> void:
	_galaxy = DialFixture.galaxy()
	_home_origin = _galaxy.home().origin_glyph


func _resolve(address: GateAddress) -> Dictionary:
	return DialResolver.resolve(address, _galaxy)


func _assert_answer(answer: Dictionary, outcome: DialOutcome.Kind, world_id: StringName) -> void:
	assert_int(answer["outcome"]).is_equal(outcome)
	assert_str(str(answer["world_id"])).is_equal(String(world_id))


## An open, unguarded world's address from home is a Lock to that world.
func test_lock() -> void:
	var answer := _resolve(DialFixture.address_of(_galaxy, DialFixture.OPEN_ID))
	_assert_answer(answer, DialOutcome.Kind.LOCK, DialFixture.OPEN_ID)


## A guarded world is a Hostile lock.
func test_hostile_lock() -> void:
	var answer := _resolve(DialFixture.address_of(_galaxy, DialFixture.GUARDED_ID))
	_assert_answer(answer, DialOutcome.Kind.HOSTILE_LOCK, DialFixture.GUARDED_ID)


## Buried and shielded Rings are Blocked.
func test_blocked() -> void:
	for id: StringName in [DialFixture.BURIED_ID, DialFixture.SHIELDED_ID]:
		_assert_answer(_resolve(DialFixture.address_of(_galaxy, id)), DialOutcome.Kind.BLOCKED, id)


## Seven coordinates no world has are No gate, with no world id.
func test_no_gate() -> void:
	var address := DialFixture.address_of(_galaxy, DialFixture.OPEN_ID)
	var swapped: Array[int] = address.coordinates.duplicate()
	var first: int = swapped[0]
	swapped[0] = swapped[1]
	swapped[1] = first
	var answer := _resolve(GateAddress.create(swapped, _home_origin))
	_assert_answer(answer, DialOutcome.Kind.NO_GATE, &"")


## The right coordinates with the wrong origin are Origin rejected, whatever the world's
## status (it comes before Blocked and the locks).
func test_right_coordinates_wrong_origin_is_origin_rejected() -> void:
	for id: StringName in [
		DialFixture.OPEN_ID, DialFixture.BURIED_ID, DialFixture.SHIELDED_ID, DialFixture.GUARDED_ID
	]:
		var address := DialFixture.address_of(_galaxy, id)
		var wrong_origin: int = _unused_glyph(address)
		var answer := _resolve(GateAddress.create(address.coordinates, wrong_origin))
		_assert_answer(answer, DialOutcome.Kind.ORIGIN_REJECTED, id)


## Wrong coordinates and a wrong origin are No gate: the coordinates are checked first.
func test_wrong_coordinates_and_wrong_origin_is_no_gate() -> void:
	var address := DialFixture.address_of(_galaxy, DialFixture.OPEN_ID)
	var coordinates: Array[int] = address.coordinates.duplicate()
	coordinates.reverse()
	var wrong_origin: int = _unused_glyph(address)
	var answer := _resolve(GateAddress.create(coordinates, wrong_origin))
	_assert_answer(answer, DialOutcome.Kind.NO_GATE, &"")


## Dialing CAIRN's own address from CAIRN is No gate.
func test_home_address_is_no_gate() -> void:
	var home: WorldRecord = _galaxy.home()
	var address: GateAddress = _galaxy.address_of(home.id, _home_origin)
	_assert_answer(_resolve(address), DialOutcome.Kind.NO_GATE, &"")


## A world's address from another Ring's origin: Origin rejected when its seven coordinates
## match the home address, otherwise No gate. Both cases occur in the fixture.
func test_address_from_another_origin_follows_the_order() -> void:
	var seen: Dictionary = {}
	for id: StringName in [DialFixture.OPEN_ID, DialFixture.GUARDED_ID]:
		var home_address := DialFixture.address_of(_galaxy, id)
		for origin: int in GateAddress.GLYPH_COUNT:
			if origin == _home_origin:
				continue
			var address: GateAddress = _galaxy.address_of(id, origin)
			var answer := _resolve(address)
			if address.coordinates == home_address.coordinates:
				_assert_answer(answer, DialOutcome.Kind.ORIGIN_REJECTED, id)
			else:
				_assert_answer(answer, DialOutcome.Kind.NO_GATE, &"")
			seen[answer["outcome"]] = true
	assert_bool(seen.has(DialOutcome.Kind.ORIGIN_REJECTED)).is_true()
	assert_bool(seen.has(DialOutcome.Kind.NO_GATE)).is_true()


## In a generated galaxy every world's home address gives the outcome of its status.
func test_every_generated_world_resolves_by_its_status() -> void:
	var anchors: Array[Vector3i] = GalaxyFixture.anchors()
	var worlds: Array[WorldRecord] = WorldGenerator.generate(
		31, anchors, GalaxyFixture.authored(anchors), GeneratorParams.new(), BalanceConfig.new()
	)
	var galaxy: GalaxyCatalogue = GalaxyCatalogue.build(worlds, anchors)
	var origin: int = galaxy.home().origin_glyph
	for world: WorldRecord in worlds:
		var answer: Dictionary = DialResolver.resolve(galaxy.address_of(world.id, origin), galaxy)
		assert_int(answer["outcome"]).is_equal(_expected(world))


static func _expected(world: WorldRecord) -> DialOutcome.Kind:
	if world.is_home:
		return DialOutcome.Kind.NO_GATE
	if world.ring_status != WorldDef.RingStatus.OPEN:
		return DialOutcome.Kind.BLOCKED
	if world.is_guarded:
		return DialOutcome.Kind.HOSTILE_LOCK
	return DialOutcome.Kind.LOCK


## The lowest glyph that is not a seal of [param address].
static func _unused_glyph(address: GateAddress) -> int:
	for glyph: int in GateAddress.GLYPH_COUNT:
		if not address.seals().has(glyph):
			return glyph
	return -1
