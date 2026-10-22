class_name ExactFloat
extends RefCounted
## Writes floats into saves exactly. A float is encoded as its 64-bit IEEE-754 pattern:
## 16 lowercase hex digits, most significant byte first, e.g. 1.0 / 3.0 is
## "3fd5555555555555" and -0.0 is "8000000000000000". JSON numbers are not used for floats
## because Godot's JSON parser drops digits when it reads them back. Pure static.
## Only lowercase is accepted, so every float has exactly one encoding and a save compares
## equal after a round trip.
## Bible: technical-architecture.md#save-system (round-trip test),
## technical-architecture.md#code-standards (Determinism and numbers)

## Length of an encoded float: 8 bytes, two hex digits each.
const ENCODED_LENGTH: int = 16
## The only characters an encoded float may contain.
const _HEX_DIGITS: String = "0123456789abcdef"


## Returns the bit pattern of [param value] as 16 lowercase hex digits, sign, NaN payload and
## all.
static func encode(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	# encode_double writes little-endian on every platform; reverse for most significant first.
	bytes.encode_double(0, value)
	bytes.reverse()
	return bytes.hex_encode()


## Returns the float whose bit pattern [param text] holds. Call is_encoded() first: any
## other text gives an unspecified value.
static func decode(text: String) -> float:
	var bytes := text.hex_decode()
	if bytes.size() != 8:
		return 0.0
	bytes.reverse()
	return bytes.decode_double(0)


## True when [param value] is a String of exactly 16 lowercase hex digits.
static func is_encoded(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.length() != ENCODED_LENGTH:
		return false
	for character: String in text:
		if not _HEX_DIGITS.contains(character):
			return false
	return true


## True when [param value] is encoded and decodes to a finite float of at least 0. NaN and
## the infinities are rejected; -0.0 is accepted.
static func is_finite_non_negative(value: Variant) -> bool:
	if not is_encoded(value):
		return false
	var text: String = value
	var number := decode(text)
	return is_finite(number) and number >= 0.0
