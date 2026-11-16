class_name AddressDraft
extends RefCounted
## The address being composed on the alien panel: seven seals, each with a firm glyph and a
## pencilled guess (or -1). A firm press fills the next seal without a firm glyph; a pencil
## press marks the next seal without either. Pressing a glyph already firm clears it. Pure.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## Seals the player composes (the eighth is CAIRN's mark).
const SEALS: int = 7

## Firm glyph per seal, -1 when empty.
var firm: Array[int] = [-1, -1, -1, -1, -1, -1, -1]
## Pencilled guess per seal, -1 when none.
var pencil: Array[int] = [-1, -1, -1, -1, -1, -1, -1]


## Presses [param glyph], firm or in [param in_pencil].
func press(glyph: int, in_pencil: bool) -> void:
	var at: int = firm.find(glyph)
	if at >= 0:
		firm[at] = -1
		return
	if in_pencil:
		var guess_at: int = pencil.find(glyph)
		if guess_at >= 0:
			pencil[guess_at] = -1
			return
		for seal: int in SEALS:
			if firm[seal] < 0 and pencil[seal] < 0:
				pencil[seal] = glyph
				return
		return
	var seal_at: int = firm.find(-1)
	if seal_at >= 0:
		firm[seal_at] = glyph


## Clears seal [param seal].
func clear(seal: int) -> void:
	if seal < 0 or seal >= SEALS:
		return
	firm[seal] = -1
	pencil[seal] = -1


## True when [param glyph] is a firm glyph.
func has(glyph: int) -> bool:
	return firm.has(glyph)


## The address with origin [param origin], or null while a seal is empty or it is malformed.
func address(origin: int) -> GateAddress:
	if firm.has(-1) or origin < 0:
		return null
	var made: GateAddress = GateAddress.create(firm, origin)
	return made if made.is_well_formed() else null


## The first glyph whose name in [param names] starts with [param typed] (case ignored), or -1.
static func find_by_name(typed: String, names: Array[String]) -> int:
	if typed.is_empty():
		return -1
	for glyph: int in names.size():
		if names[glyph].to_lower().begins_with(typed):
			return glyph
	return -1
