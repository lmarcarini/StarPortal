class_name CandidateSearch
extends RefCounted
## The counting engine behind CandidateCounter: how many sequences of distinct glyphs satisfy
## a constraint set, without enumerating them. CandidateReduction first turns the constraints
## into allowed seals, required glyphs and order edges, with the core glyphs in groups of
## interchangeable ones.
##
## A dynamic program then walks the seals in order. Its state is how many glyphs of each core
## group are placed, plus what it needs to fill the seals left open with optional glyphs. At
## each seal it either leaves the seal open or places a glyph of a group allowed there whose
## predecessor groups are wholly placed. Open seals are filled in one of two ways:
## - By count, when every optional glyph is barred from at most one seal: inclusion-exclusion
##   over the barred (glyph, seal) pairs. An open seal may "pick" one glyph barred there, with
##   sign -1; a state keeps the open and picked counts, and ends with a falling factorial.
## - By mask, otherwise: the state keeps the open seals, filled at the end by a table over seal
##   subsets for the restricted glyphs, times a falling factorial for the free ones.
## Bible: gate-and-address-spec.md#player-tools, gate-and-address-spec.md#puzzle-tuning-rules

## Count mode: the picked count sits this many bits above the open count.
const PICK_SHIFT: int = 4

var _facts: CandidateReduction
var _length: int = 0
var _full: int = 0
## Per group: bit offset of its placed count in a state's counts, the mask of that field, and
## the group's size.
var _shifts: Array[int] = []
var _fields: Array[int] = []
var _sizes: Array[int] = []
## Counts with every required group wholly placed, and the mask of those fields.
var _required_value: int = 0
var _required_fields: int = 0
## Per seal index: bits of the required groups with no allowed seal after it.
var _dead_after: Array[int] = []
## Seals an optional glyph may fill.
var _open_seals: int = 0
## True to track open seals by mask; false to track open and picked counts.
var _by_mask: bool = false
## Count mode: per seal index, optional glyphs barred only there; and all optional glyphs.
var _picks: Array[int] = []
var _pool: int = 0
## Per-bucket facts that _advance() reads and _place() adjusts.
var _seal_index: int = 0
var _not_full_required: int = 0
var _pending: int = 0


## Number of sequences of [param length] distinct glyphs from [param alphabet] (duplicates
## ignored) that satisfy every constraint in [param constraints]. 0 when the length or the
## alphabet is beyond CandidateReduction.MAX_LENGTH / MAX_ALPHABET.
static func count_of(
	constraints: Array[AddressConstraint], alphabet: Array[int], length: int
) -> int:
	var facts: CandidateReduction = CandidateReduction.reduce(constraints, alphabet, length)
	if facts.impossible:
		return 0
	var search := CandidateSearch.new()
	search._prepare(facts)
	return search._count()


func _prepare(facts: CandidateReduction) -> void:
	_facts = facts
	_length = facts.length
	_full = facts.full
	var shift: int = 0
	for index: int in facts.groups.size():
		var size: int = facts.groups[index].size()
		var field: int = (1 << _bit_length(size)) - 1
		_shifts.append(shift)
		_fields.append(field)
		_sizes.append(size)
		if facts.group_required[index]:
			_required_value |= size << shift
			_required_fields |= field << shift
		shift += _bit_length(size)
	for seal_index: int in _length:
		var later: int = _full & ~((2 << seal_index) - 1)
		var dead: int = 0
		for index: int in _sizes.size():
			if facts.group_required[index] and facts.group_masks[index] & later == 0:
				dead |= 1 << index
		_dead_after.append(dead)
	_prepare_open(facts)


func _prepare_open(facts: CandidateReduction) -> void:
	_open_seals = _full if facts.free_glyphs > 0 else 0
	_pool = facts.free_glyphs
	_picks.resize(_length)
	_picks.fill(0)
	for mask: int in facts.restricted:
		_open_seals |= mask
		_pool += 1
		var barred: int = _full & ~mask
		if _bit_count(barred) == 1:
			_picks[_bit_length(barred) - 1] += 1
		else:
			_by_mask = true


func _count() -> int:
	var states: Dictionary[int, Dictionary] = {0: {0: 1}}
	for seal_index: int in _length:
		states = _advance(states, seal_index)
		if states.is_empty():
			return 0
	return _total(states)


## One seal. States are bucketed by placed counts (counts -> {open part: ways}), so the checks
## run once per bucket. Each state leaves the seal open or places a glyph of an allowed group
## whose predecessor groups are wholly placed; a required group allowed only here is forced.
func _advance(states: Dictionary[int, Dictionary], seal_index: int) -> Dictionary[int, Dictionary]:
	_seal_index = seal_index
	var seal_bit: int = 1 << seal_index
	var forced: int = _forced_at(seal_bit)
	var next: Dictionary[int, Dictionary] = {}
	for counts: int in states:
		var opens: Dictionary = states[counts]
		var full_groups: int = _read_counts(counts)
		if forced < 0 and _open_seals & seal_bit != 0 and _is_alive():
			_leave_open(_bucket(next, counts), opens, seal_index)
		for index: int in _sizes.size():
			if full_groups & (1 << index) != 0 or _facts.group_masks[index] & seal_bit == 0:
				continue
			var before: int = _facts.group_before[index]
			if (forced < 0 or index == forced) and full_groups & before == before:
				_place(next, counts, opens, index)
	return next


## Sets the per-state facts for [param counts]; returns the bits of the wholly placed groups.
func _read_counts(counts: int) -> int:
	var full_groups: int = 0
	_not_full_required = 0
	_pending = 0
	for index: int in _sizes.size():
		var missing: int = _sizes[index] - _count_of_group(counts, index)
		if missing == 0:
			full_groups |= 1 << index
		elif _facts.group_required[index]:
			_not_full_required |= 1 << index
			_pending += missing
	return full_groups


func _count_of_group(counts: int, index: int) -> int:
	return (counts >> _shifts[index]) & _fields[index]


## Adds the states of [param opens] with one more glyph of group [param index] placed: any of
## the group's unplaced glyphs, so each way times their number.
func _place(next: Dictionary[int, Dictionary], counts: int, opens: Dictionary, index: int) -> void:
	var choices: int = _sizes[index] - _count_of_group(counts, index)
	var saved_required: int = _not_full_required
	var saved_pending: int = _pending
	if _facts.group_required[index]:
		_pending -= 1
		if choices == 1:
			_not_full_required &= ~(1 << index)
	if _is_alive():
		var target: Dictionary = _bucket(next, counts + (1 << _shifts[index]))
		for open_part: int in opens:
			var ways: int = opens[open_part]
			target[open_part] = target.get(open_part, 0) + ways * choices
	_not_full_required = saved_required
	_pending = saved_pending


func _forced_at(seal_bit: int) -> int:
	for index: int in _sizes.size():
		if _facts.group_required[index] and _facts.group_masks[index] == seal_bit:
			return index
	return -1


## False when, after this seal, a required glyph can no longer be placed.
func _is_alive() -> bool:
	if _not_full_required & _dead_after[_seal_index] != 0:
		return false
	return _pending <= _length - _seal_index - 1


func _bucket(next: Dictionary[int, Dictionary], counts: int) -> Dictionary:
	if not next.has(counts):
		next[counts] = {}
	return next[counts]


## Adds the states of [param opens] with seal [param seal_index] left open: by mask, or by
## count with one more open seal, and also a signed pick of each glyph barred only there.
func _leave_open(target: Dictionary, opens: Dictionary, seal_index: int) -> void:
	var picks: int = _picks[seal_index]
	for open_part: int in opens:
		var ways: int = opens[open_part]
		if _by_mask:
			var opened: int = open_part | (1 << seal_index)
			target[opened] = target.get(opened, 0) + ways
			continue
		target[open_part + 1] = target.get(open_part + 1, 0) + ways
		if picks > 0:
			var picked: int = open_part + 1 + (1 << PICK_SHIFT)
			target[picked] = target.get(picked, 0) - ways * picks


func _total(states: Dictionary[int, Dictionary]) -> int:
	var fills: PackedInt64Array = _restricted_fills() if _by_mask else PackedInt64Array()
	var memo: Dictionary[int, int] = {}
	var total: int = 0
	for counts: int in states:
		if counts & _required_fields != _required_value:
			continue
		var opens: Dictionary = states[counts]
		for open_part: int in opens:
			if not memo.has(open_part):
				memo[open_part] = _fill_value(open_part, fills)
			var ways: int = opens[open_part]
			total += ways * memo[open_part]
	return total


## Ways to fill the open seals that [param open_part] describes with distinct optional glyphs
## (signed in count mode).
func _fill_value(open_part: int, fills: PackedInt64Array) -> int:
	if _by_mask:
		return _fill_ways(open_part, fills)
	var picked: int = open_part >> PICK_SHIFT
	var open_count: int = open_part & ((1 << PICK_SHIFT) - 1)
	return _falling(_pool - picked, open_count - picked)


## Entry s: ways to put distinct restricted glyphs on exactly the seals of subset s.
func _restricted_fills() -> PackedInt64Array:
	var fills := PackedInt64Array()
	fills.resize(1 << _length)
	fills[0] = 1
	for mask: int in _facts.restricted:
		for subset: int in range(_full, -1, -1):
			if fills[subset] == 0:
				continue
			var spare: int = mask & ~subset
			while spare != 0:
				var bit: int = spare & -spare
				fills[subset | bit] += fills[subset]
				spare &= spare - 1
	return fills


## Ways to fill exactly the [param open] seals with distinct optional glyphs.
func _fill_ways(open: int, fills: PackedInt64Array) -> int:
	var open_count: int = _bit_count(open)
	var total: int = 0
	var subset: int = open
	while true:
		var rest: int = open_count - _bit_count(subset)
		total += fills[subset] * _falling(_facts.free_glyphs, rest)
		if subset == 0:
			break
		subset = (subset - 1) & open
	return total


static func _falling(n: int, k: int) -> int:
	if k > n:
		return 0
	var product: int = 1
	for step: int in k:
		product *= n - step
	return product


static func _bit_count(value: int) -> int:
	var bits: int = 0
	var rest: int = value
	while rest != 0:
		rest &= rest - 1
		bits += 1
	return bits


static func _bit_length(value: int) -> int:
	var bits: int = 0
	while value >> bits != 0:
		bits += 1
	return bits
