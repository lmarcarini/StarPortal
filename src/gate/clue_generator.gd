class_name ClueGenerator
extends RefCounted
## Writes a dossier of true clues for a target world: fragments, pictures, sky charts, ordinal
## comparisons and neighbour records, measured from the home Ring's origin, added greedily until
## the candidate count falls within the limits and at least min_kinds kinds are mixed. Pure
## static; randomness comes only from the rng passed in.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#puzzle-tuning-rules

## Tries to build a clue of a kind that is not redundant before skipping its slot.
const _TRIES_PER_SLOT: int = 6
## Penalty per missing kind in a set's score, far above any candidate-count excess.
const _MISSING_KIND_PENALTY: int = 1_000_000


## Returns the dossier clues for [param target_id]: true, with constraints, source, grade, text
## key and arguments set; the caller sets id, dossier_id and received_tick. When no attempt in
## params.max_attempts meets the limits, returns the best set found and warns. Empty for an
## unknown target.
static func generate_dossier(
	target_id: StringName,
	galaxy: GalaxyCatalogue,
	rng: RandomNumberGenerator,
	params: ClueSetParams
) -> Array[ClueRecord]:
	var context: ClueContext = ClueContext.create(target_id, galaxy, rng)
	var best: Array[ClueRecord] = []
	if context == null:
		push_warning("ClueGenerator: unknown target %s" % target_id)
		return best
	var best_score: int = -1
	for _attempt: int in params.max_attempts:
		var draft: Array[ClueRecord] = _draft(context, params)
		var score: int = _score(draft, context.origin, params)
		if score == 0:
			return draft
		if best_score < 0 or score < best_score:
			best = draft
			best_score = score
	push_warning("ClueGenerator: no dossier within limits for %s; using best" % target_id)
	return best


## Returns how many addresses dialed from [param origin] satisfy every constraint of every clue.
static func count_candidates(clues: Array[ClueRecord], origin: int) -> int:
	var constraints: Array[AddressConstraint] = []
	for clue: ClueRecord in clues:
		constraints.append_array(clue.constraints)
	return CandidateCounter.count(constraints, origin)


## One attempt: kinds in a random order first (all five kinds once), then random kinds, until
## the limits are met or max_clues is reached.
static func _draft(context: ClueContext, params: ClueSetParams) -> Array[ClueRecord]:
	var clues: Array[ClueRecord] = []
	var kinds: Array[int] = []
	for kind: int in ClueRecord.KIND_NAMES.size():
		kinds.append(kind)
	var order: Array[int] = ClueCommon.shuffled(context.rng, kinds)
	for slot: int in params.max_clues:
		var kind: int = order[slot] if slot < order.size() else kinds[_random_index(context, kinds)]
		var clue: ClueRecord = _new_clue(context, kind, clues)
		if clue == null:
			continue
		clues.append(clue)
		if _score(clues, context.origin, params) == 0:
			break
	return clues


static func _random_index(context: ClueContext, values: Array[int]) -> int:
	return context.rng.randi_range(0, values.size() - 1)


## A clue of [param kind] that says something the [param existing] clues do not, or null.
static func _new_clue(
	context: ClueContext, kind: ClueRecord.Kind, existing: Array[ClueRecord]
) -> ClueRecord:
	for _try: int in _TRIES_PER_SLOT:
		var clue: ClueRecord = _make(context, kind)
		if clue != null and not _is_redundant(clue, existing):
			return clue
	return null


static func _make(context: ClueContext, kind: ClueRecord.Kind) -> ClueRecord:
	match kind:
		ClueRecord.Kind.FRAGMENT:
			return FragmentClues.make(context)
		ClueRecord.Kind.PICTORIAL:
			return PictorialClues.make(context)
		ClueRecord.Kind.SKY_CHART:
			return SkyChartClues.make(context)
		ClueRecord.Kind.ORDINAL:
			return OrdinalClues.make(context)
	return NeighbourClues.make(context)


## True when every constraint of [param clue] already appears in [param existing].
static func _is_redundant(clue: ClueRecord, existing: Array[ClueRecord]) -> bool:
	for constraint: AddressConstraint in clue.constraints:
		if not _is_stated(constraint, existing):
			return false
	return true


static func _is_stated(constraint: AddressConstraint, existing: Array[ClueRecord]) -> bool:
	for clue: ClueRecord in existing:
		for other: AddressConstraint in clue.constraints:
			if other.equals(constraint):
				return true
	return false


## 0 when [param clues] mix enough kinds and leave a candidate count within the limits;
## otherwise a penalty that grows with the shortfall.
static func _score(clues: Array[ClueRecord], origin: int, params: ClueSetParams) -> int:
	var kinds: Dictionary = {}
	for clue: ClueRecord in clues:
		kinds[clue.kind] = true
	var score: int = maxi(params.min_kinds - kinds.size(), 0) * _MISSING_KIND_PENALTY
	if clues.is_empty():
		return score + _MISSING_KIND_PENALTY
	var candidates: int = count_candidates(clues, origin)
	score += maxi(candidates - params.max_candidates, 0)
	score += maxi(params.min_candidates - candidates, 0)
	return score
