class_name WorkbenchEdits
extends RefCounted
## The Address Workbench's edits as pure functions: each takes the current constraint list and
## returns a new full list for one SetWorkbenchCommand, never changing its input. Also reads
## what the list says about one glyph or seal, for the palette and the slots.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#architecture-overview (the UI never mutates state)

## What the constraints say about one glyph, as the palette shows it.
enum GlyphStatus { NEUTRAL, RULED_OUT, IN_ADDRESS }

## Kinds that put their glyphs in the address.
const _IN_ADDRESS_KINDS: Array[AddressConstraint.Kind] = [
	AddressConstraint.Kind.INCLUDED,
	AddressConstraint.Kind.GLYPH_AT,
	AddressConstraint.Kind.EXACT_SET
]


## Returns a copy of [param constraints] (new objects, so the caller can never edit a list
## that lives in the state).
static func copy(constraints: Array[AddressConstraint]) -> Array[AddressConstraint]:
	var copies: Array[AddressConstraint] = []
	for constraint: AddressConstraint in constraints:
		copies.append(AddressConstraint.from_dict(constraint.to_dict()))
	return copies


## Returns [param constraints] with [param constraint] added at the end, unless an equal one is
## already there.
static func with_added(
	constraints: Array[AddressConstraint], constraint: AddressConstraint
) -> Array[AddressConstraint]:
	var result: Array[AddressConstraint] = copy(constraints)
	for existing: AddressConstraint in result:
		if existing.equals(constraint):
			return result
	result.append(constraint)
	return result


## Returns [param constraints] without the first one equal to [param removed]
## (AddressConstraint.equals); unchanged when none is. Matching by value, not position, keeps a
## remove on the constraint the player saw even when the list it applies to has moved on.
static func without(
	constraints: Array[AddressConstraint], removed: AddressConstraint
) -> Array[AddressConstraint]:
	var result: Array[AddressConstraint] = copy(constraints)
	for position: int in result.size():
		if result[position].equals(removed):
			result.remove_at(position)
			break
	return result


## Places [param glyph] at [param seal]: drops any glyph already placed at that seal and any
## other seal this glyph was placed at, then adds GLYPH_AT.
static func placed(
	constraints: Array[AddressConstraint], seal: int, glyph: int
) -> Array[AddressConstraint]:
	var kept: Array[AddressConstraint] = []
	for constraint: AddressConstraint in copy(constraints):
		var is_place: bool = constraint.kind == AddressConstraint.Kind.GLYPH_AT
		if is_place and (constraint.seal == seal or constraint.glyphs[0] == glyph):
			continue
		kept.append(constraint)
	return with_added(kept, AddressConstraint.glyph_at(seal, glyph))


## Rules [param glyph] out (EXCLUDED, dropping an INCLUDED of it), or takes the ruling back
## when it is already ruled out.
static func toggled_excluded(
	constraints: Array[AddressConstraint], glyph: int
) -> Array[AddressConstraint]:
	return _toggled(
		constraints, glyph, AddressConstraint.Kind.EXCLUDED, AddressConstraint.Kind.INCLUDED
	)


## Marks [param glyph] as in the address (INCLUDED, dropping an EXCLUDED of it), or takes the
## mark back when it is already there.
static func toggled_included(
	constraints: Array[AddressConstraint], glyph: int
) -> Array[AddressConstraint]:
	return _toggled(
		constraints, glyph, AddressConstraint.Kind.INCLUDED, AddressConstraint.Kind.EXCLUDED
	)


## Replaces exactly seven INCLUDED glyphs with one EXACT_SET of them (a sky chart's unordered
## set); unchanged unless can_group() is true.
static func grouped_as_set(constraints: Array[AddressConstraint]) -> Array[AddressConstraint]:
	if not can_group(constraints):
		return copy(constraints)
	var kept: Array[AddressConstraint] = []
	for constraint: AddressConstraint in copy(constraints):
		if constraint.kind != AddressConstraint.Kind.INCLUDED:
			kept.append(constraint)
	return with_added(kept, AddressConstraint.exact_set(included_glyphs(constraints)))


## True when exactly seven glyphs are marked INCLUDED.
static func can_group(constraints: Array[AddressConstraint]) -> bool:
	return included_glyphs(constraints).size() == GateAddress.COORDINATE_COUNT


## Returns the glyphs marked INCLUDED, in the order they were marked.
static func included_glyphs(constraints: Array[AddressConstraint]) -> Array[int]:
	var glyphs: Array[int] = []
	for constraint: AddressConstraint in constraints:
		if (
			constraint.kind == AddressConstraint.Kind.INCLUDED
			and not glyphs.has(constraint.glyphs[0])
		):
			glyphs.append(constraint.glyphs[0])
	return glyphs


## Returns RULED_OUT when [param glyph] is EXCLUDED, IN_ADDRESS when it is INCLUDED, placed at
## a seal or in an EXACT_SET, else NEUTRAL.
static func glyph_status(constraints: Array[AddressConstraint], glyph: int) -> GlyphStatus:
	var status: GlyphStatus = GlyphStatus.NEUTRAL
	for constraint: AddressConstraint in constraints:
		if not constraint.glyphs.has(glyph):
			continue
		if constraint.kind == AddressConstraint.Kind.EXCLUDED:
			return GlyphStatus.RULED_OUT
		if _IN_ADDRESS_KINDS.has(constraint.kind):
			status = GlyphStatus.IN_ADDRESS
	return status


## Returns the glyph placed at [param seal] (the first GLYPH_AT for it), or -1.
static func glyph_at_seal(constraints: Array[AddressConstraint], seal: int) -> int:
	for constraint: AddressConstraint in constraints:
		if constraint.kind == AddressConstraint.Kind.GLYPH_AT and constraint.seal == seal:
			return constraint.glyphs[0]
	return -1


static func _toggled(
	constraints: Array[AddressConstraint], glyph: int, kind: int, opposite: int
) -> Array[AddressConstraint]:
	var kept: Array[AddressConstraint] = []
	var had: bool = false
	for constraint: AddressConstraint in copy(constraints):
		var is_single: bool = constraint.kind == kind or constraint.kind == opposite
		if is_single and constraint.glyphs[0] == glyph:
			had = had or constraint.kind == kind
			continue
		kept.append(constraint)
	if had:
		return kept
	var added: AddressConstraint = (
		AddressConstraint.excluded(glyph)
		if kind == AddressConstraint.Kind.EXCLUDED
		else AddressConstraint.included(glyph)
	)
	return with_added(kept, added)
