extends RefCounted
## Test fixture for the Address Workbench: a paused Simulation over the real content (Registry)
## and a generated world's real address.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

const TEST_SEED: int = 20_261_022
const SCENE_PATH: String = "res://src/ui/gate_room/console/dial_console.tscn"


## Returns a paused simulation of a new game, with its galaxy and balance set.
static func build_simulation() -> Simulation:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build(GameState.new_game(TEST_SEED, defs.balance), defs)
	assert(built.is_ok, "workbench fixture: GameSetup failed")
	return built.value


## Returns the address of the first world other than CAIRN, dialed from CAIRN.
static func target_address(state: GameState) -> GateAddress:
	var home: WorldRecord = state.galaxy.home()
	for world: WorldRecord in state.galaxy.all_worlds():
		if world.id != home.id:
			return state.galaxy.address_of(world.id, home.origin_glyph)
	return null


## Returns a new Workbench scene instance.
static func instantiate() -> Workbench:
	return (load(SCENE_PATH) as PackedScene).instantiate() as Workbench
