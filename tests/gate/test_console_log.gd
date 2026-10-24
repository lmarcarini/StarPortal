## Tests for ConsoleLog: a far Ring's console lists the 2 to 4 procedural worlds nearest to it,
## ties by id, never CAIRN, an authored world or itself; the count is a stable hash of the id,
## and the same galaxy always gives the same list.
## Bible: gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## gate-and-address-spec.md#probing-the-unknown
extends GdUnitTestSuite

const GalaxyFixture := preload("res://tests/gate/galaxy_fixture.gd")
const SEED: int = 20_261_024


func _real_galaxy() -> GalaxyCatalogue:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var galaxy_seed: int = RandomState.derive_seed(SEED, &"galaxy")
	return GameSetup.build_galaxy(galaxy_seed, defs)


## A record at [param offset] from anchor 3, authored or not.
func _record(id: StringName, offset: Vector3i, authored: bool = false) -> WorldRecord:
	var record := WorldRecord.new()
	record.id = id
	record.position_ly = GalaxyFixture.anchors()[3] + offset
	record.is_authored = authored
	return record


## A small galaxy: home, an authored world right next to the reader, two procedural worlds at
## the same distance (ids out of order), and a far one.
func _small_galaxy() -> GalaxyCatalogue:
	var anchors: Array[Vector3i] = GalaxyFixture.anchors()
	var worlds: Array[WorldRecord] = [WorldRecord.from_def(GalaxyFixture.home(anchors))]
	worlds.append(_record(&"reader", Vector3i.ZERO))
	worlds.append(_record(&"story", Vector3i(5, 0, 0), true))
	worlds.append(_record(&"world_b", Vector3i(0, 50, 0)))
	worlds.append(_record(&"world_a", Vector3i(0, -50, 0)))
	worlds.append(_record(&"world_c", Vector3i(0, 0, 90)))
	worlds.append(_record(&"world_d", Vector3i(400, 0, 0)))
	worlds.append(_record(&"world_e", Vector3i(900, 0, 0)))
	return GalaxyCatalogue.build(worlds, anchors)


## The count is 2..4, the stable FNV-1a hash of the id, and fixed for known ids.
func test_entry_count_is_stable() -> void:
	assert_int(ConsoleLog.stable_hash("")).is_equal(-3750763034362895579)
	assert_int(ConsoleLog.stable_hash("a")).is_equal(-5808556873153909620)
	assert_int(ConsoleLog.entry_count(&"world_0000")).is_equal(2)
	assert_int(ConsoleLog.entry_count(&"world_0001")).is_equal(3)
	assert_int(ConsoleLog.entry_count(&"world_0002")).is_equal(4)
	var counts: Dictionary[int, bool] = {}
	for index: int in 60:
		var count: int = ConsoleLog.entry_count(StringName("world_%04d" % index))
		assert_int(count).is_between(ConsoleLog.MIN_ENTRIES, ConsoleLog.MAX_ENTRIES)
		counts[count] = true
	assert_int(counts.size()).is_equal(3)


## Nearest first, ties by id, skipping CAIRN, the authored world and the reader itself.
func test_lists_nearest_procedural_worlds() -> void:
	var listed := ConsoleLog.listed_worlds(&"reader", _small_galaxy())
	var expected: Array[StringName] = [&"world_a", &"world_b", &"world_c", &"world_d"]
	var count: int = ConsoleLog.entry_count(&"reader")
	assert_array(listed).is_equal(expected.slice(0, count))


## An unknown world lists nothing.
func test_unknown_world_lists_nothing() -> void:
	assert_array(ConsoleLog.listed_worlds(&"nowhere", _small_galaxy())).is_empty()


## On the real galaxy: same seed, same lists; 2..4 entries, never CAIRN, an authored world or
## the reader, and an authored world's console lists procedural worlds too.
func test_real_galaxy_lists_are_stable_and_procedural() -> void:
	var first: GalaxyCatalogue = _real_galaxy()
	var second: GalaxyCatalogue = _real_galaxy()
	var readers: Array[StringName] = [first.home().id]
	for record: WorldRecord in first.all_worlds().slice(0, 40):
		readers.append(record.id)
	for reader: StringName in readers:
		var listed := ConsoleLog.listed_worlds(reader, first)
		assert_array(listed).is_equal(ConsoleLog.listed_worlds(reader, second))
		assert_int(listed.size()).is_equal(ConsoleLog.entry_count(reader))
		assert_array(listed).not_contains([reader])
		for id: StringName in listed:
			var record: WorldRecord = first.get_world(id)
			assert_bool(record.is_home or record.is_authored).is_false()
