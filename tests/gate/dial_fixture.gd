extends RefCounted
## Test fixture for dialing: a small hand-made galaxy over the galaxy fixture's anchors, with
## the home Ring and one world of each kind (open, buried, shielded, guarded), and a GameState
## wired to it with a large, full capacitor bank. Never reads data/.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy

const GalaxyFixture := preload("res://tests/gate/galaxy_fixture.gd")

const OPEN_ID: StringName = &"world_open"
const BURIED_ID: StringName = &"world_buried"
const SHIELDED_ID: StringName = &"world_shielded"
const GUARDED_ID: StringName = &"world_guarded"
## Offset of each fixture world from the anchor it sits next to.
const NEAR_OFFSET_LY := Vector3i(120, 80, 10)
## Capacity of the fixture's bank, large enough for any fixture dial.
const CAPACITY_MWH: float = 100_000.0
## The fixture bank's charge rate: the starting plant's 30 MW less the starting rooms' 4 MW.
const CHARGE_RATE_MW: int = 26


## Returns the fixture galaxy: home first, then the open, buried, shielded and guarded worlds,
## each next to its own anchor (never the home origin's).
static func galaxy() -> GalaxyCatalogue:
	var anchors: Array[Vector3i] = GalaxyFixture.anchors()
	var home_def: WorldDef = GalaxyFixture.home(anchors)
	var worlds: Array[WorldRecord] = [WorldRecord.from_def(home_def)]
	var ids: Array[StringName] = [OPEN_ID, BURIED_ID, SHIELDED_ID, GUARDED_ID]
	var anchor_index: int = 1
	for id: StringName in ids:
		if anchor_index == home_def.origin_glyph:
			anchor_index += 1
		var record := WorldRecord.new()
		record.id = id
		record.position_ly = anchors[anchor_index] + NEAR_OFFSET_LY
		record.origin_glyph = 0
		worlds.append(record)
		anchor_index += 4
	worlds[2].ring_status = WorldDef.RingStatus.BURIED
	worlds[3].ring_status = WorldDef.RingStatus.SHIELDED
	worlds[4].is_guarded = true
	return GalaxyCatalogue.build(worlds, anchors)


## Returns a new game wired to the fixture galaxy and [param balance] (a default one when
## null, then holding CAPACITY_MWH per bank), the real RoomDefs and one built bank, full and
## charging at CHARGE_RATE_MW, paused or running as [param paused] says.
static func state(balance: BalanceConfig = null, paused: bool = true) -> GameState:
	var config: BalanceConfig = balance
	if config == null:
		config = BalanceConfig.new()
		config.capacitor_bank_capacity_mwh = CAPACITY_MWH
	var game: GameState = GameState.new_game(1, config)
	game.balance = config
	game.galaxy = galaxy()
	PowerFixture.add_bank(game, CHARGE_RATE_MW)
	game.power.stored_mwh = config.capacitor_bank_capacity_mwh
	game.clock.is_paused = paused
	return game


## Returns a Simulation over [param game] with the real systems in tick order.
static func simulation(game: GameState) -> Simulation:
	var systems: Array[SimSystem] = [PowerSystem.new(game.balance), GateSystem.new()]
	return Simulation.new(game, systems)


## Returns the home Ring's address of world [param id] in [param catalogue].
static func address_of(catalogue: GalaxyCatalogue, id: StringName) -> GateAddress:
	return catalogue.address_of(id, catalogue.home().origin_glyph)
