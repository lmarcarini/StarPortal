class_name JsonLimits
extends RefCounted
## Limits of numbers that survive a JSON round trip. JSON numbers are read back as doubles,
## so only whole numbers up to 2^53 in absolute value come back exactly. The one place that
## defines that limit; every other script refers to [constant MAX_EXACT_INT].
## Bible: technical-architecture.md#data-model, technical-architecture.md#save-system

## Largest whole number a JSON number (a double) holds exactly: 2^53.
const MAX_EXACT_INT: int = 9007199254740992


## True for an int, or a whole float, with absolute value at most [constant MAX_EXACT_INT].
## Ints are compared as ints, so 2^53 + 1 is rejected; NaN and infinities are rejected.
static func is_exact_int(value: Variant) -> bool:
	if value is int:
		var whole: int = value
		return whole >= -MAX_EXACT_INT and whole <= MAX_EXACT_INT
	if not value is float:
		return false
	var number: float = value
	return number == floorf(number) and absf(number) <= float(MAX_EXACT_INT)
