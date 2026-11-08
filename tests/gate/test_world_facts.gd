## Tests for WorldFacts and WorldFactRules: procedural facts are deterministic per id and follow
## section 3's distribution; authored worlds read their WorldDef; the scene mirrors the facts.
## Bible: docs/content/m3-beyond-the-ring.md section 3 (Worlds)
extends GdUnitTestSuite

const SAMPLE_SIZE: int = 10_000
const SEED: int = 20_261_107


func _real_galaxy() -> GalaxyCatalogue:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	return GameSetup.build_galaxy(RandomState.derive_seed(SEED, &"galaxy"), defs)


func _summary(facts: WorldFacts) -> Array:
	var target_ids: Array[String] = []
	for target: WorldTarget in facts.targets:
		target_ids.append("%s:%s:%s" % [target.id, target.name_key, target.is_object])
	return [
		facts.biome,
		facts.atmosphere,
		facts.temperature_c,
		facts.radiation,
		facts.biohazard,
		facts.life,
		facts.structures,
		facts.threat,
		target_ids,
	]


## The same id always derives the same facts.
func test_derivation_is_deterministic() -> void:
	for index: int in 50:
		var id := StringName("world_%04d" % index)
		var first: Array = _summary(WorldFactRules.derive(id, false))
		var second: Array = _summary(WorldFactRules.derive(id, false))
		assert_array(second).is_equal(first)


## A guarded world is always HIGH.
func test_guarded_is_high() -> void:
	for index: int in 200:
		var facts := WorldFactRules.derive(StringName("world_%04d" % index), true)
		assert_int(facts.threat).is_equal(WorldDef.Threat.HIGH)


## Over a large sample of unguarded ids about 15% are MED, the rest LOW, never HIGH.
func test_threat_distribution() -> void:
	var counts: Array[int] = [0, 0, 0, 0]
	for index: int in SAMPLE_SIZE:
		counts[WorldFactRules.threat_for("world_%05d" % index, false)] += 1
	var med_percent: float = 100.0 * counts[WorldDef.Threat.MED] / SAMPLE_SIZE
	assert_float(med_percent).is_between(13.5, 16.5)
	assert_int(counts[WorldDef.Threat.HIGH]).is_zero()
	assert_int(counts[WorldDef.Threat.UNKNOWN]).is_zero()


## Every derived world has known true facts, no people, every biome appears, and 0 to 2
## distinct targets drawn from its structures' pool.
func test_derived_facts_are_well_formed() -> void:
	var biomes: Dictionary[int, bool] = {}
	for index: int in 2000:
		var facts := WorldFactRules.derive(StringName("world_%04d" % index), false)
		biomes[facts.biome] = true
		assert_int(facts.life).is_not_equal(WorldDef.Life.UNKNOWN)
		assert_int(facts.life).is_not_equal(WorldDef.Life.PEOPLE)
		assert_int(facts.biohazard).is_not_equal(WorldDef.Biohazard.UNKNOWN)
		assert_int(facts.structures).is_not_equal(WorldDef.Structures.UNKNOWN)
		assert_int(facts.targets.size()).is_between(0, WorldFactRules.MAX_PROCEDURAL_TARGETS)
		if facts.targets.size() == 2:
			assert_str(facts.targets[0].id).is_not_equal(facts.targets[1].id)
	assert_int(biomes.size()).is_equal(WorldDef.Biome.size())


## The real galaxy's procedural worlds derive their facts from their records (guards HIGH).
func test_galaxy_worlds_have_facts() -> void:
	var galaxy := _real_galaxy()
	for record: WorldRecord in galaxy.all_worlds():
		var facts: WorldFacts = WorldFactRules.facts_of(record)
		assert_object(facts).is_not_null()
		if record.is_guarded:
			assert_int(facts.threat).is_equal(WorldDef.Threat.HIGH)
	assert_object(WorldFactRules.facts_for_id(galaxy, &"no_such_world")).is_null()


## The authored worlds read their WorldDef: STILLWATER is LOW and breathable with the
## footprints and the iron object (an object), MILESTONE MED with the bronze pegs, SILL and
## LINTEL LOW and airless.
func test_authored_worlds() -> void:
	var galaxy := _real_galaxy()
	var stillwater: WorldFacts = WorldFactRules.facts_for_id(galaxy, &"world_stillwater")
	assert_int(stillwater.threat).is_equal(WorldDef.Threat.LOW)
	assert_int(stillwater.atmosphere).is_equal(WorldDef.Atmosphere.BREATHABLE)
	assert_int(stillwater.targets.size()).is_equal(2)
	assert_bool(stillwater.find_target(&"iron_object").is_object).is_true()
	assert_bool(stillwater.find_target(&"footprints").is_object).is_false()
	var milestone: WorldFacts = WorldFactRules.facts_for_id(galaxy, &"world_milestone")
	assert_int(milestone.threat).is_equal(WorldDef.Threat.MED)
	assert_object(milestone.find_target(&"bronze_pegs")).is_not_null()
	assert_int(stillwater.biohazard).is_equal(WorldDef.Biohazard.NONE)
	assert_int(stillwater.sky).is_equal(WorldDef.SkyColour.OVERCAST)
	var lintel: WorldFacts = WorldFactRules.facts_for_id(galaxy, &"world_lintel")
	assert_int(lintel.temperature_c).is_equal(-70)
	assert_int(lintel.radiation).is_equal(WorldDef.Radiation.RAISED)
	assert_int(lintel.sky).is_equal(WorldDef.SkyColour.BLACK)
	var sill: WorldFacts = WorldFactRules.facts_for_id(galaxy, &"world_sill")
	assert_int(sill.sky).is_equal(WorldDef.SkyColour.VIOLET)
	assert_int(sill.sun).is_equal(WorldDef.Sun.ORANGE)
	for id: StringName in [&"world_sill", &"world_lintel"]:
		var facts: WorldFacts = WorldFactRules.facts_for_id(galaxy, id)
		assert_int(facts.threat).is_equal(WorldDef.Threat.LOW)
		assert_int(facts.atmosphere).is_equal(WorldDef.Atmosphere.NONE)


## The scene carries the facts a picture shows.
func test_scene_mirrors_facts() -> void:
	var facts := WorldFactRules.derive(&"world_0042", false)
	var scene: WorldScene = facts.scene()
	assert_int(scene.biome).is_equal(facts.biome)
	assert_int(scene.atmosphere).is_equal(facts.atmosphere)
	assert_int(scene.sky).is_equal(facts.sky)
	assert_int(scene.sun).is_equal(facts.sun)
	assert_str(scene.world_id).is_equal(&"world_0042")
	assert_int(scene.variation_seed).is_equal(ConsoleLog.stable_hash("world_0042"))
	assert_int(scene.life).is_equal(facts.life)
	assert_int(scene.structures).is_equal(facts.structures)
	assert_int(scene.targets.size()).is_equal(facts.targets.size())


## Procedural skies follow the air (airless never blue, overcast hides the sun), and two
## worlds always differ by their scene's seed.
func test_procedural_sky_and_seed() -> void:
	var seeds: Dictionary[int, bool] = {}
	for index: int in 500:
		var facts := WorldFactRules.derive(StringName("world_%04d" % index), false)
		if facts.atmosphere == WorldDef.Atmosphere.NONE:
			assert_int(facts.sky).is_not_equal(WorldDef.SkyColour.BLUE)
		if facts.sky == WorldDef.SkyColour.OVERCAST:
			assert_int(facts.sun).is_equal(WorldDef.Sun.HIDDEN)
		seeds[facts.scene().variation_seed] = true
	assert_int(seeds.size()).is_equal(500)


## A WorldDef reports an UNKNOWN true fact, a guarded world not HIGH and repeated targets.
func test_world_def_content_errors() -> void:
	var def := WorldDef.new()
	def.id = &"world_test"
	assert_array(def.get_content_errors({})).is_empty()
	def.is_guarded = true
	def.life = WorldDef.Life.UNKNOWN
	var target := WorldTargetDef.new()
	target.id = &"thing"
	target.name_key = &"KEY"
	def.targets = [target, target]
	assert_int(def.get_content_errors({}).size()).is_equal(3)
