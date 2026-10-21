class_name RandomState
extends RefCounted
## Saved state of the simulation's randomness: one seeded stream per system.
## Each stream's seed comes from [member base_seed] and the system id only, so it does not
## depend on the order streams are first requested. Seeds and states are saved as strings,
## because 64-bit integers lose precision as JSON numbers.
## Bible: technical-architecture.md#simulation-clock-and-commands (Randomness),
## technical-architecture.md#code-standards (Determinism and numbers)

const _FNV_OFFSET_HI: int = 0xcbf29ce4
const _FNV_OFFSET_LO: int = 0x84222325
const _FNV_PRIME_LOW_BITS: int = 0x1b3
const _MASK_32: int = 0xffffffff

## Seed every system stream derives from. Named to avoid shadowing the global seed().
var base_seed: int = 0

var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


## Returns the stream for [param system_id], created on first use, then reused.
func stream(system_id: StringName) -> RandomNumberGenerator:
	if _streams.has(system_id):
		return _streams[system_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(base_seed, system_id)
	_streams[system_id] = rng
	return rng


## Returns JSON-safe data for saving. Every 64-bit integer is written as a decimal string.
func to_dict() -> Dictionary:
	var streams_data: Dictionary = {}
	for system_id: StringName in _streams:
		var rng: RandomNumberGenerator = _streams[system_id]
		streams_data[String(system_id)] = {"seed": str(rng.seed), "state": str(rng.state)}
	return {"base_seed": str(base_seed), "streams": streams_data}


## Builds a RandomState from saved [param data], restoring every stream's seed and state.
## Integers saved as strings are parsed exactly; a plain number is still accepted.
static func from_dict(data: Dictionary) -> RandomState:
	var random := RandomState.new()
	random.base_seed = _to_int64(data.get("base_seed", random.base_seed))
	var streams_data: Variant = data.get("streams", {})
	if not streams_data is Dictionary:
		return random
	var streams_dict: Dictionary = streams_data
	for system_id: Variant in streams_dict:
		var entry_data: Variant = streams_dict[system_id]
		if not entry_data is Dictionary:
			continue
		var entry: Dictionary = entry_data
		random._streams[StringName(str(system_id))] = _restore_stream(entry)
	return random


## Derives a stream seed: 64-bit FNV-1a over the 8 little-endian bytes of
## [param from_seed] followed by the UTF-8 bytes of [param system_id].
## Computed here, not with String.hash(), so it is stable across platforms and versions.
static func derive_seed(from_seed: int, system_id: StringName) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, from_seed)
	bytes.append_array(String(system_id).to_utf8_buffer())
	return fnv1a_64(bytes)


## Returns the 64-bit FNV-1a hash of [param bytes] as a signed int (two's complement).
## The hash is kept in two 32-bit halves so no multiplication overflows.
static func fnv1a_64(bytes: PackedByteArray) -> int:
	var hi: int = _FNV_OFFSET_HI
	var lo: int = _FNV_OFFSET_LO
	for byte: int in bytes:
		lo = lo ^ byte
		# h * (2^40 + 0x1b3) mod 2^64, split into high and low 32-bit words.
		var low_product: int = lo * _FNV_PRIME_LOW_BITS
		var new_hi: int = hi * _FNV_PRIME_LOW_BITS + (low_product >> 32) + (lo << 8)
		hi = new_hi & _MASK_32
		lo = low_product & _MASK_32
	var out := PackedByteArray()
	out.resize(8)
	out.encode_u32(0, lo)
	out.encode_u32(4, hi)
	return out.decode_s64(0)


static func _restore_stream(entry: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _to_int64(entry.get("seed", 0))
	rng.state = _to_int64(entry.get("state", rng.state))
	return rng


static func _to_int64(value: Variant) -> int:
	if value is String:
		var text: String = value
		return text.to_int()
	return type_convert(value, TYPE_INT)
