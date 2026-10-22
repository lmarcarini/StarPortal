extends RefCounted
## Test fixture for the clue generator: the fixture galaxy as a catalogue and a seeded choice of
## target worlds. Never reads data/.
## Bible: gate-and-address-spec.md#clue-types-and-reliability

const Fixture := preload("res://tests/gate/galaxy_fixture.gd")
const GALAXY_SEED: int = 5151
const TARGET_SEED: int = 61


## Returns a catalogue of the fixture galaxy.
static func galaxy() -> GalaxyCatalogue:
	var anchors: Array[Vector3i] = Fixture.anchors()
	var worlds: Array[WorldRecord] = WorldGenerator.generate(
		GALAXY_SEED, anchors, Fixture.authored(anchors), GeneratorParams.new(), BalanceConfig.new()
	)
	return GalaxyCatalogue.build(worlds, anchors)


## Returns [param count] ids of procedural worlds, chosen with a seeded rng (repeats possible).
static func targets(catalogue: GalaxyCatalogue, count: int) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = TARGET_SEED
	var worlds: Array[WorldRecord] = catalogue.all_worlds().filter(
		func(world: WorldRecord) -> bool: return not world.is_authored
	)
	var ids: Array[StringName] = []
	for _index: int in count:
		ids.append(worlds[rng.randi_range(0, worlds.size() - 1)].id)
	return ids


## Returns the unique placeholder names ("{name}") in [param text], sorted.
static func placeholders(text: String) -> Array[String]:
	var names: Array[String] = []
	var regex := RegEx.create_from_string("\\{(\\w+)\\}")
	for found: RegExMatch in regex.search_all(text):
		if not names.has(found.get_string(1)):
			names.append(found.get_string(1))
	names.sort()
	return names
