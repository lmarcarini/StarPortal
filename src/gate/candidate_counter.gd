class_name CandidateCounter
extends RefCounted
## How many addresses still fit a set of constraints, and which ones when few remain: the
## Address Workbench's "5,040 possible". Pure static functions; counting is combinatorial (see
## CandidateSearch), never an enumeration of the 3.4 * 10^10 sequences.
## Bible: gate-and-address-spec.md#player-tools, gate-and-address-spec.md#puzzle-tuning-rules,
## gate-and-address-spec.md#clue-types-and-reliability


## A depth-first listing in progress: what list_in() needs at every step.
class Listing:
	extends RefCounted
	var constraints: Array[AddressConstraint] = []
	var alphabet: Array[int] = []
	var length: int = 0
	var limit: int = 0
	## Glyph -> the seals it may take at all (CandidateReduction), to skip hopeless branches.
	var masks: Dictionary[int, int] = {}
	var found: Array[PackedInt32Array] = []


## Number of addresses dialed from a Ring with origin glyph [param origin] whose seven
## coordinates satisfy every constraint: count_in() over the 35 non-origin glyphs, length 7.
## 0 when the origin is not a glyph from 0 to 35.
static func count(constraints: Array[AddressConstraint], origin: int) -> int:
	if not _is_glyph(origin):
		return 0
	return count_in(constraints, _alphabet_without(origin), GateAddress.COORDINATE_COUNT)


## Number of sequences of [param length] distinct glyphs from [param alphabet] that satisfy
## every constraint. A null or malformed-shape constraint fits nothing, so the count is 0.
## Supports a length up to CandidateReduction.MAX_LENGTH and an alphabet of up to
## CandidateReduction.MAX_ALPHABET glyphs; beyond that it returns 0.
static func count_in(
	constraints: Array[AddressConstraint], alphabet: Array[int], length: int
) -> int:
	return CandidateSearch.count_of(constraints, alphabet, length)


## Up to [param limit] addresses that fit, as count() counts them, in lexicographic order of
## their coordinates; each ends in [param origin]. Empty when the origin is not a glyph.
static func list(
	constraints: Array[AddressConstraint], origin: int, limit: int
) -> Array[GateAddress]:
	var addresses: Array[GateAddress] = []
	if not _is_glyph(origin):
		return addresses
	var alphabet: Array[int] = _alphabet_without(origin)
	var length: int = GateAddress.COORDINATE_COUNT
	for sequence: PackedInt32Array in list_in(constraints, alphabet, length, limit):
		var coordinates: Array[int] = []
		coordinates.assign(sequence)
		addresses.append(GateAddress.create(coordinates, origin))
	return addresses


## Up to [param limit] sequences that count_in() counts, in lexicographic order. A depth-first
## search over seals that skips every branch the counter says is empty and stops at the limit.
## Lengths and alphabets beyond count_in()'s limits list nothing.
static func list_in(
	constraints: Array[AddressConstraint], alphabet: Array[int], length: int, limit: int
) -> Array[PackedInt32Array]:
	var listing := Listing.new()
	listing.constraints = constraints
	listing.alphabet = _sorted_unique(alphabet)
	listing.length = length
	listing.limit = limit
	listing.masks = CandidateReduction.reduce(constraints, listing.alphabet, length).masks
	var total: int = count_in(constraints, listing.alphabet, length)
	if total > 0 and limit > 0:
		var prefix: Array[int] = []
		_extend(listing, prefix, total)
	return listing.found


## True when [param address] is not null and satisfies every constraint.
static func is_satisfied(address: GateAddress, constraints: Array[AddressConstraint]) -> bool:
	if address == null:
		return false
	return _fits(address.coordinates, constraints)


## Lists the completions of [param prefix], which has [param expected] (> 0) of them, in order.
static func _extend(listing: Listing, prefix: Array[int], expected: int) -> void:
	if prefix.size() == listing.length:
		listing.found.append(PackedInt32Array(prefix))
		return
	var remaining: int = expected
	for glyph: int in listing.alphabet:
		if remaining <= 0 or listing.found.size() >= listing.limit:
			return
		if prefix.has(glyph) or listing.masks[glyph] & (1 << prefix.size()) == 0:
			continue
		prefix.append(glyph)
		var completions: int = _completions(listing, prefix)
		if completions > 0:
			_extend(listing, prefix, completions)
			remaining -= completions
		prefix.pop_back()


## Number of sequences that start with [param prefix] and fit.
static func _completions(listing: Listing, prefix: Array[int]) -> int:
	if prefix.size() == listing.length:
		return 1 if _fits(prefix, listing.constraints) else 0
	var pinned: Array[AddressConstraint] = listing.constraints.duplicate()
	for index: int in prefix.size():
		pinned.append(AddressConstraint.glyph_at(index + 1, prefix[index]))
	return count_in(pinned, listing.alphabet, listing.length)


static func _fits(coordinates: Array[int], constraints: Array[AddressConstraint]) -> bool:
	for constraint: AddressConstraint in constraints:
		if constraint == null or not constraint.is_satisfied_by_coordinates(coordinates):
			return false
	return true


static func _is_glyph(glyph: int) -> bool:
	return glyph >= 0 and glyph < GateAddress.GLYPH_COUNT


static func _alphabet_without(origin: int) -> Array[int]:
	var alphabet: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			alphabet.append(glyph)
	return alphabet


static func _sorted_unique(glyphs: Array[int]) -> Array[int]:
	var unique: Array[int] = []
	for glyph: int in glyphs:
		if not unique.has(glyph):
			unique.append(glyph)
	unique.sort()
	return unique
