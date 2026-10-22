class_name ClueContext
extends RefCounted
## What every clue kind needs while one dossier is generated: the galaxy, the target and its
## address as dialed from the home Ring, the rng, and (on first use) the reference worlds a
## neighbour clue can name. Built once per dossier.
## Bible: gate-and-address-spec.md#clue-types-and-reliability

## Fewest leading seals a neighbour reference must share with the target.
const MIN_SHARED_SEALS: int = 2

var galaxy: GalaxyCatalogue
var target_id: StringName
## The target's address from the home Ring's origin.
var address: GateAddress
## The home Ring's origin glyph.
var origin: int = 0
var rng: RandomNumberGenerator
## Neighbour candidates, parallel arrays: world, its address from the home origin, and how many
## leading seals it shares with the target.
var ref_worlds: Array[WorldRecord] = []
var ref_addresses: Array[GateAddress] = []
var ref_shared: Array[int] = []
var _refs_ready: bool = false


## Returns a context for [param target_id] in [param galaxy], or null when the target is
## unknown.
static func create(
	target_id: StringName, galaxy: GalaxyCatalogue, rng: RandomNumberGenerator
) -> ClueContext:
	if galaxy == null or galaxy.get_world(target_id) == null:
		return null
	var context := ClueContext.new()
	context.galaxy = galaxy
	context.target_id = target_id
	context.rng = rng
	context.origin = galaxy.home().origin_glyph
	context.address = galaxy.address_of(target_id, context.origin)
	return context


## Fills the neighbour reference lists once: designated worlds other than the target that share
## at least MIN_SHARED_SEALS leading seals with it, but not all seven.
func ensure_references() -> void:
	if _refs_ready:
		return
	_refs_ready = true
	for world: WorldRecord in galaxy.all_worlds():
		if world.id == target_id or world.designation.is_empty():
			continue
		var other: GateAddress = galaxy.address_of(world.id, origin)
		var shared: int = _shared_prefix(other.coordinates)
		if shared >= MIN_SHARED_SEALS and shared < GateAddress.COORDINATE_COUNT:
			ref_worlds.append(world)
			ref_addresses.append(other)
			ref_shared.append(shared)


## Number of leading seals [param other] shares with the target address.
func _shared_prefix(other: Array[int]) -> int:
	var shared: int = 0
	while shared < other.size() and other[shared] == address.coordinates[shared]:
		shared += 1
	return shared
