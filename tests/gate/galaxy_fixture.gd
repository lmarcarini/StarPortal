extends RefCounted
## Test fixture for the world generator and galaxy catalogue: 36 seeded anchors in the home
## domain's 30,000 x 30,000 x 3,000 ly slab, at least 2,500 ly apart, and an authored home world
## built in code whose origin glyph is not among its seven nearest anchors. Never reads data/.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

const ANCHOR_SEED: int = 20_261_022
const MIN_ANCHOR_SPACING_LY: int = 2500
## Home sits this far from anchor 0, so some anchor is well within early reach.
const HOME_OFFSET_LY := Vector3i(600, -450, 150)
const HOME_ID: StringName = &"world_cairn"


## Returns 36 anchors, indexed by glyph, inside GeneratorParams' default bounds.
static func anchors() -> Array[Vector3i]:
	var extents: Vector3i = GeneratorParams.new().half_extents_ly
	var rng := RandomNumberGenerator.new()
	rng.seed = ANCHOR_SEED
	var result: Array[Vector3i] = []
	var min_squared: int = MIN_ANCHOR_SPACING_LY * MIN_ANCHOR_SPACING_LY
	while result.size() < GateAddress.GLYPH_COUNT:
		var candidate := Vector3i(
			rng.randi_range(-extents.x, extents.x),
			rng.randi_range(-extents.y, extents.y),
			rng.randi_range(-extents.z, extents.z)
		)
		var is_spaced: bool = result.all(
			func(other: Vector3i) -> bool:
				return AddressRule.squared_distance(candidate, other) >= min_squared
		)
		if is_spaced:
			result.append(candidate)
	return result


## Returns the authored home world near anchor 0, with its farthest anchor as origin glyph.
static func home(anchor_positions: Array[Vector3i]) -> WorldDef:
	var extents: Vector3i = GeneratorParams.new().half_extents_ly
	var def := WorldDef.new()
	def.id = HOME_ID
	def.is_home = true
	def.position_ly = (anchor_positions[0] + HOME_OFFSET_LY).clamp(-extents, extents)
	var sorted: Array[int] = AddressRule.nearest_anchors(
		def.position_ly, anchor_positions, -1, GateAddress.GLYPH_COUNT
	)
	def.origin_glyph = sorted[sorted.size() - 1]
	return def


## Returns the authored worlds: just the home world.
static func authored(anchor_positions: Array[Vector3i]) -> Array[WorldDef]:
	var worlds: Array[WorldDef] = [home(anchor_positions)]
	return worlds
