class_name ConsoleLog
extends RefCounted
## What a far Ring's console lists in its log of recent dials: the procedural worlds nearest to
## it. Story puzzles open new regions; consoles fill them in, so the log never lists CAIRN or an
## authored (story) world. Pure static over the derived galaxy; nothing is saved.
## Bible: gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## gate-and-address-spec.md#probing-the-unknown (the far Ring's console)

## Fewest worlds a console lists.
const MIN_ENTRIES: int = 2
## Most worlds a console lists.
const MAX_ENTRIES: int = 4

## FNV-1a 64-bit offset basis and prime, for a hash that never changes between runs or engine
## versions (String.hash() may).
const _FNV_OFFSET: int = -3750763034362895579
const _FNV_PRIME: int = 1099511628211


## The worlds a far Ring's console lists: the nearest procedural worlds to [param world_id] by
## distance (ties by id), excluding CAIRN and authored worlds; the count (2..4) comes from a stable
## hash of the world id, so it never changes between runs. Empty when the world is unknown.
static func listed_worlds(world_id: StringName, galaxy: GalaxyCatalogue) -> Array[StringName]:
	var listed: Array[StringName] = []
	var origin: WorldRecord = galaxy.get_world(world_id)
	if origin == null:
		return listed
	var candidates: Array[Array] = []
	for record: WorldRecord in galaxy.all_worlds():
		if record.id == world_id or record.is_home or record.is_authored:
			continue
		var distance: int = AddressRule.squared_distance(record.position_ly, origin.position_ly)
		candidates.append([distance, String(record.id)])
	candidates.sort_custom(_nearer_first)
	for index: int in mini(entry_count(world_id), candidates.size()):
		listed.append(StringName(str(candidates[index][1])))
	return listed


## How many worlds the console of [param world_id] lists, MIN_ENTRIES..MAX_ENTRIES.
static func entry_count(world_id: StringName) -> int:
	var spread: int = MAX_ENTRIES - MIN_ENTRIES + 1
	return MIN_ENTRIES + posmod(stable_hash(String(world_id)), spread)


## FNV-1a 64-bit hash of the UTF-8 bytes of [param text].
static func stable_hash(text: String) -> int:
	var hash_value: int = _FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		hash_value = (hash_value ^ byte) * _FNV_PRIME
	return hash_value


## Orders [distance squared, id] pairs by distance, then by id.
static func _nearer_first(a: Array, b: Array) -> bool:
	var distance_a: int = a[0]
	var distance_b: int = b[0]
	if distance_a != distance_b:
		return distance_a < distance_b
	return str(a[1]) < str(b[1])
