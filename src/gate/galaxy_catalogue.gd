class_name GalaxyCatalogue
extends RefCounted
## The generated galaxy, read only: worlds by id, the home Ring, each world's address from any
## origin, and "which world, if any, is at this address?". The address index of an origin is
## built on its first lookup; after that a lookup is one Dictionary read.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy

var _worlds: Array[WorldRecord] = []
var _by_id: Dictionary[StringName, WorldRecord] = {}
var _anchors_ly: Array[Vector3i] = []
var _home: WorldRecord
## Per origin glyph: address key (GateAddress.key()) -> world; empty until first needed.
var _by_address: Array[Dictionary] = []
## Per origin glyph: whether its entry in _by_address has been built.
var _is_indexed: Array[bool] = []


## Returns a catalogue of [param worlds] (as WorldGenerator.generate() returns them) over
## [param anchors_ly], the 36 anchors indexed by glyph. Exactly one world must be the home Ring
## and ids must be unique (asserted).
static func build(worlds: Array[WorldRecord], anchors_ly: Array[Vector3i]) -> GalaxyCatalogue:
	var catalogue := GalaxyCatalogue.new()
	catalogue._worlds = worlds.duplicate()
	catalogue._anchors_ly = anchors_ly.duplicate()
	for record: WorldRecord in worlds:
		assert(not catalogue._by_id.has(record.id), "GalaxyCatalogue: repeated id %s" % record.id)
		catalogue._by_id[record.id] = record
		if record.is_home:
			assert(catalogue._home == null, "GalaxyCatalogue: more than one home world")
			catalogue._home = record
	assert(catalogue._home != null, "GalaxyCatalogue: no home world")
	for _origin: int in GateAddress.GLYPH_COUNT:
		catalogue._by_address.append({})
		catalogue._is_indexed.append(false)
	return catalogue


## Returns the world with [param id], or null when no world has it.
func get_world(id: StringName) -> WorldRecord:
	return _by_id.get(id)


## Returns every world in generation order: authored first, then procedural.
func all_worlds() -> Array[WorldRecord]:
	return _worlds.duplicate()


## Returns the home Ring's world (CAIRN).
func home() -> WorldRecord:
	return _home


## Returns a copy of the 36 anchor positions, indexed by glyph.
func anchors_ly() -> Array[Vector3i]:
	return _anchors_ly.duplicate()


## Returns the address of world [param world_id] dialed from a Ring with origin glyph
## [param origin]; null when the world is unknown or the origin is not a glyph.
func address_of(world_id: StringName, origin: int) -> GateAddress:
	var record: WorldRecord = get_world(world_id)
	if record == null or not _is_glyph(origin):
		return null
	return AddressRule.address_of(record.position_ly, _anchors_ly, origin)


## Returns the world whose address from [param origin] has exactly these seven
## [param coordinates], in order; null when none does or the input is not a possible address.
func find_by_coordinates(coordinates: Array[int], origin: int) -> WorldRecord:
	if not _is_glyph(origin) or coordinates.size() != GateAddress.COORDINATE_COUNT:
		return null
	var key: String = GateAddress.create(coordinates, origin).key()
	return _index_for(origin).get(key)


## The address index of [param origin], built on first use.
func _index_for(origin: int) -> Dictionary:
	if _is_indexed[origin]:
		return _by_address[origin]
	var index: Dictionary = _by_address[origin]
	for record: WorldRecord in _worlds:
		var key: String = AddressRule.address_of(record.position_ly, _anchors_ly, origin).key()
		assert(not index.has(key), "GalaxyCatalogue: two worlds share address %s" % key)
		index[key] = record
	_is_indexed[origin] = true
	return index


## True when [param glyph] is a glyph index, 0..35.
static func _is_glyph(glyph: int) -> bool:
	return glyph >= 0 and glyph < GateAddress.GLYPH_COUNT
