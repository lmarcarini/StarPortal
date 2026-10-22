class_name ContentCheckWorlds
extends RefCounted
## Content checks 3 and 4: the anchor fields, the authored worlds and their addresses. Pure
## functions that return one line per problem.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

## Least distance between two anchors of the home domain, in light years.
const MIN_ANCHOR_SPACING_LY: int = 2_500
## The id of the player's home world.
const HOME_ID: StringName = &"world_cairn"
## How many nearest anchors form an address (and may not include the origin).
const NEAREST: int = GateAddress.COORDINATE_COUNT


## Returns the problems of [param field]: not exactly 36 positions, a coordinate beyond
## AddressRule.MAX_COORDINATE_LY and, when [param is_spaced], two anchors closer than
## MIN_ANCHOR_SPACING_LY.
static func check_field(field: AnchorFieldDef, is_spaced: bool) -> Array[String]:
	var errors: Array[String] = []
	var count: int = field.positions_ly.size()
	if count != GateAddress.GLYPH_COUNT:
		errors.append("anchor field %s has %d positions, expected 36" % [field.id, count])
	var in_bounds: bool = true
	for index: int in count:
		if not AddressRule.is_within_bounds(field.positions_ly[index]):
			in_bounds = false
			errors.append(
				(
					"anchor field %s: anchor %d at %s is beyond %d ly"
					% [field.id, index, field.positions_ly[index], AddressRule.MAX_COORDINATE_LY]
				)
			)
	if is_spaced and in_bounds:
		errors.append_array(_check_spacing(field))
	return errors


## Returns the problems of the authored [param worlds] over [param anchors_ly]: an origin glyph
## outside 0..35, a position beyond the bounds, not exactly one home world, a home world that is
## not world_cairn, and a home origin among its seven nearest anchors.
static func check_worlds(worlds: Array[WorldDef], anchors_ly: Array[Vector3i]) -> Array[String]:
	var errors: Array[String] = []
	var homes: Array[WorldDef] = []
	for world: WorldDef in worlds:
		if world.origin_glyph < 0 or world.origin_glyph >= GateAddress.GLYPH_COUNT:
			errors.append(
				"world %s has origin glyph %d, expected 0..35" % [world.id, world.origin_glyph]
			)
		if not AddressRule.is_within_bounds(world.position_ly):
			errors.append("world %s at %s is beyond the bounds" % [world.id, world.position_ly])
		if world.is_home:
			homes.append(world)
	if homes.size() != 1:
		errors.append("expected exactly one home world, found %d" % homes.size())
		return errors
	if homes[0].id != HOME_ID:
		errors.append("the home world is %s, expected %s" % [homes[0].id, HOME_ID])
	errors.append_array(_check_home_origin(homes[0], anchors_ly))
	return errors


## Returns one line for every pair of authored [param worlds] that share an address from some
## origin 0..35. Worlds out of bounds are skipped (check_worlds reports them); empty when
## [param anchors_ly] does not have 36 anchors.
static func check_unique_addresses(
	worlds: Array[WorldDef], anchors_ly: Array[Vector3i]
) -> Array[String]:
	var errors: Array[String] = []
	if anchors_ly.size() != GateAddress.GLYPH_COUNT:
		return errors
	var placed: Array[WorldDef] = worlds.filter(
		func(world: WorldDef) -> bool: return AddressRule.is_within_bounds(world.position_ly)
	)
	for origin: int in GateAddress.GLYPH_COUNT:
		var by_key: Dictionary[String, StringName] = {}
		for world: WorldDef in placed:
			var key: String = AddressRule.address_of(world.position_ly, anchors_ly, origin).key()
			if by_key.has(key):
				errors.append(
					(
						"worlds %s and %s share address %s from origin %d"
						% [by_key[key], world.id, key, origin]
					)
				)
			by_key[key] = world.id
	return errors


static func _check_spacing(field: AnchorFieldDef) -> Array[String]:
	var errors: Array[String] = []
	var least: int = MIN_ANCHOR_SPACING_LY * MIN_ANCHOR_SPACING_LY
	for first: int in field.positions_ly.size():
		for second: int in range(first + 1, field.positions_ly.size()):
			var squared: int = AddressRule.squared_distance(
				field.positions_ly[first], field.positions_ly[second]
			)
			if squared < least:
				errors.append(
					(
						"anchor field %s: anchors %d and %d are %d ly apart, least %d"
						% [field.id, first, second, int(sqrt(squared)), MIN_ANCHOR_SPACING_LY]
					)
				)
	return errors


static func _check_home_origin(home: WorldDef, anchors_ly: Array[Vector3i]) -> Array[String]:
	var is_checkable: bool = (
		anchors_ly.size() == GateAddress.GLYPH_COUNT
		and AddressRule.is_within_bounds(home.position_ly)
	)
	if not is_checkable:
		return []
	var nearest: Array[int] = AddressRule.nearest_anchors(home.position_ly, anchors_ly, -1, NEAREST)
	if nearest.has(home.origin_glyph):
		return [
			(
				"home world %s: origin %d is among its seven nearest anchors"
				% [home.id, home.origin_glyph]
			)
		]
	return []
