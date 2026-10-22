class_name DialOutcome
extends RefCounted
## The five results a Ring can report for a dial, and their saved keys.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy

## NO_GATE: no Ring at those coordinates. BLOCKED: a Ring exists but is buried, busy or
## shielded. ORIGIN_REJECTED: the last seal is not this Ring's origin glyph. LOCK: wormhole
## open. HOSTILE_LOCK: wormhole open, far side guarded.
enum Kind { NO_GATE, BLOCKED, ORIGIN_REJECTED, LOCK, HOSTILE_LOCK }

## Saved keys of the kinds, indexed by Kind value.
const _KEYS: Array[StringName] = [
	&"no_gate", &"blocked", &"origin_rejected", &"lock", &"hostile_lock"
]


## Returns the stable key of [param kind], e.g. &"no_gate"; &"" for a value outside Kind.
static func to_key(kind: Kind) -> StringName:
	if kind < 0 or kind >= _KEYS.size():
		return &""
	return _KEYS[kind]


## Returns the Kind whose key is [param key], or -1 when no kind has that key. Returns an int
## because an enum cannot hold -1.
static func from_key(key: StringName) -> int:
	return _KEYS.find(key)


## True for the outcomes that open a wormhole: LOCK and HOSTILE_LOCK.
static func is_lock(kind: Kind) -> bool:
	return kind == Kind.LOCK or kind == Kind.HOSTILE_LOCK
