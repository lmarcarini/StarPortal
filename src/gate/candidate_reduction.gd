class_name CandidateReduction
extends RefCounted
## First half of CandidateSearch: reduces a constraint set over an alphabet to per-glyph facts.
## Each glyph gets the seals it may take (a bit mask, bit 0 = seal 1; 0 means absent), whether it
## must be present, and "x before y" order edges. Order edges are then settled: a glyph after an
## absent one is absent, a glyph before a required one is required, and a glyph with k glyphs
## that must come before it can only be at a seal after k (none, if it is on a cycle).
##
## The core is every required glyph and every glyph in a live order edge, split into groups of
## interchangeable glyphs (same seals, requirement and edges), so the counter tracks how many
## of a group are placed instead of which. Every other present-capable glyph is optional: either
## unrestricted (free) or limited to some seals (restricted).
## Bible: gate-and-address-spec.md#player-tools, gate-and-address-spec.md#puzzle-tuning-rules

## Longest sequence supported; seal masks and state keys must fit in an int.
const MAX_LENGTH: int = 10
## Largest alphabet supported.
const MAX_ALPHABET: int = 48

## Number of seals.
var length: int = 0
## Mask of every seal.
var full: int = 0
## True when nothing can fit.
var impossible: bool = false
## Glyph -> seals it may take.
var masks: Dictionary[int, int] = {}
## Glyphs that must be present.
var required: Dictionary[int, bool] = {}
## Order edges (x before y).
var edges: Array[Vector2i] = []
## Core groups: the glyphs of each.
var groups: Array[PackedInt32Array] = []
## Per group: seals its glyphs may take.
var group_masks: Array[int] = []
## Per group: whether its glyphs must be present.
var group_required: Array[bool] = []
## Per group: bits of the groups that must be wholly placed before any of its glyphs.
var group_before: Array[int] = []
## Seal masks of the optional glyphs limited to some seals.
var restricted: Array[int] = []
## Number of optional glyphs allowed at every seal.
var free_glyphs: int = 0


## Reduces [param constraints] over [param alphabet] (duplicates ignored) for sequences of
## [param length] glyphs.
static func reduce(
	constraints: Array[AddressConstraint], alphabet: Array[int], length: int
) -> CandidateReduction:
	var reduction := CandidateReduction.new()
	reduction.length = length
	reduction.full = (1 << clampi(length, 0, MAX_LENGTH)) - 1
	for glyph: int in alphabet:
		reduction.masks[glyph] = reduction.full
	if length < 0 or length > MAX_LENGTH or reduction.masks.size() > MAX_ALPHABET:
		reduction.impossible = true
		return reduction
	for constraint: AddressConstraint in constraints:
		reduction._apply(constraint)
	reduction._settle()
	reduction._build_groups()
	return reduction


func _apply(constraint: AddressConstraint) -> void:
	if not _is_usable(constraint):
		impossible = true
		return
	var first: int = constraint.glyphs[0] if not constraint.glyphs.is_empty() else -1
	match constraint.kind:
		AddressConstraint.Kind.GLYPH_AT:
			_place(constraint.seal, first)
		AddressConstraint.Kind.GLYPH_NOT_AT:
			if masks.has(first) and constraint.seal >= 1 and constraint.seal <= length:
				masks[first] &= ~(1 << (constraint.seal - 1))
		AddressConstraint.Kind.EXCLUDED:
			if masks.has(first):
				masks[first] = 0
		AddressConstraint.Kind.INCLUDED:
			_require(first)
		AddressConstraint.Kind.EXACT_SET:
			_exact(constraint.glyphs)
		AddressConstraint.Kind.NEARER_THAN:
			_order(first, constraint.glyphs[1])


## False for null, an unknown kind or the wrong glyph count: such a constraint fits nothing.
static func _is_usable(constraint: AddressConstraint) -> bool:
	if constraint == null:
		return false
	var counts: Array[int] = AddressConstraint.GLYPH_COUNTS
	if constraint.kind < 0 or constraint.kind >= counts.size():
		return false
	var kind: int = constraint.kind
	return kind == AddressConstraint.Kind.EXACT_SET or constraint.glyphs.size() == counts[kind]


func _place(seal: int, glyph: int) -> void:
	if seal < 1 or seal > length:
		impossible = true
		return
	_require(glyph)
	if masks.has(glyph):
		masks[glyph] &= 1 << (seal - 1)


func _require(glyph: int) -> void:
	if not masks.has(glyph):
		impossible = true
		return
	required[glyph] = true


func _exact(glyphs: Array[int]) -> void:
	var wanted: Dictionary[int, bool] = {}
	for glyph: int in glyphs:
		wanted[glyph] = true
	if wanted.size() != glyphs.size() or glyphs.size() != length:
		impossible = true
		return
	for glyph: int in masks:
		if not wanted.has(glyph):
			masks[glyph] = 0
	for glyph: int in glyphs:
		_require(glyph)


func _order(nearer: int, farther: int) -> void:
	if not masks.has(farther):
		return
	if nearer == farther or not masks.has(nearer):
		masks[farther] = 0
		return
	edges.append(Vector2i(nearer, farther))


## Applies the order-edge consequences until nothing changes. Masks only shrink and the
## required set only grows, so this ends.
func _settle() -> void:
	var changed: bool = true
	while changed:
		changed = false
		for edge: Vector2i in edges:
			if masks[edge.x] == 0 and masks[edge.y] != 0:
				masks[edge.y] = 0
				changed = true
			if masks[edge.y] != 0 and required.has(edge.y) and not required.has(edge.x):
				required[edge.x] = true
				changed = true
		for edge: Vector2i in edges:
			changed = _limit_by_ancestors(edge.y) or changed


## Glyph [param glyph] needs every glyph before it placed earlier: it is absent if it is its own
## ancestor or has at least `length` of them, else it cannot take the first seals.
func _limit_by_ancestors(glyph: int) -> bool:
	var ancestors: Dictionary[int, bool] = _ancestors(glyph)
	var limited: int = masks[glyph]
	if ancestors.has(glyph) or ancestors.size() >= length:
		limited = 0
	else:
		limited &= ~((1 << ancestors.size()) - 1)
	if limited == masks[glyph]:
		return false
	masks[glyph] = limited
	return true


## Glyphs that must precede [param glyph] through live order edges.
func _ancestors(glyph: int) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	var pending: Array[int] = [glyph]
	while not pending.is_empty():
		var current: int = pending.pop_back()
		for edge: Vector2i in edges:
			if edge.y == current and _is_live(edge) and not found.has(edge.x):
				found[edge.x] = true
				pending.append(edge.x)
	return found


func _is_live(edge: Vector2i) -> bool:
	return masks[edge.x] != 0 and masks[edge.y] != 0


func _build_groups() -> void:
	var core: Dictionary[int, bool] = required.duplicate()
	for edge: Vector2i in edges:
		if _is_live(edge):
			core[edge.x] = true
			core[edge.y] = true
	for glyph: int in core:
		if masks[glyph] == 0:
			impossible = true
	if required.size() > length:
		impossible = true
	var glyphs: Array[int] = []
	glyphs.assign(core.keys())
	glyphs.sort()
	var group_of: Dictionary[int, int] = _group_glyphs(glyphs)
	for edge: Vector2i in edges:
		if _is_live(edge):
			group_before[group_of[edge.y]] |= 1 << group_of[edge.x]
	for glyph: int in masks:
		if not core.has(glyph) and masks[glyph] != 0:
			_add_optional(masks[glyph])


## Splits [param glyphs] into interchangeable groups; returns glyph -> group index.
func _group_glyphs(glyphs: Array[int]) -> Dictionary[int, int]:
	var by_key: Dictionary[String, int] = {}
	var group_of: Dictionary[int, int] = {}
	for glyph: int in glyphs:
		var key: String = _symmetry_key(glyph)
		if not by_key.has(key):
			by_key[key] = groups.size()
			groups.append(PackedInt32Array())
			group_masks.append(masks[glyph])
			group_required.append(required.has(glyph))
			group_before.append(0)
		var index: int = by_key[key]
		groups[index].append(glyph)
		group_of[glyph] = index
	return group_of


## Equal for two glyphs that can be swapped without changing any constraint.
func _symmetry_key(glyph: int) -> String:
	var before: Array[int] = []
	var after: Array[int] = []
	for edge: Vector2i in edges:
		if not _is_live(edge):
			continue
		if edge.y == glyph:
			before.append(edge.x)
		if edge.x == glyph:
			after.append(edge.y)
	before.sort()
	after.sort()
	return "%d|%s|%s|%s" % [masks[glyph], required.has(glyph), before, after]


func _add_optional(mask: int) -> void:
	if mask == full:
		free_glyphs += 1
	else:
		restricted.append(mask)
