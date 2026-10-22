class_name ContentCheckClues
extends RefCounted
## Content check 6: generated dossiers. Pure functions: the keys a clue points at must exist in
## clues.csv, and enough dossiers must leave a candidate count within the tuning limits.
## Bible: gate-and-address-spec.md#puzzle-tuning-rules,
## gate-and-address-spec.md#clue-types-and-reliability

## Share of dossiers, in percent, that must land within the candidate limits.
const MIN_PERCENT_WITHIN: int = 95


## Returns one line per key of [param clues] (text key or source key) that is missing from
## [param keys], the keys of clues.csv. Each missing key is named once.
static func check_keys(clues: Array[ClueRecord], keys: Dictionary[String, bool]) -> Array[String]:
	var errors: Array[String] = []
	var reported: Dictionary[String, bool] = {}
	for clue: ClueRecord in clues:
		for key: StringName in [clue.text_key, clue.source_key]:
			if keys.has(String(key)) or reported.has(String(key)):
				continue
			reported[String(key)] = true
			errors.append("clue %s: key '%s' is not in clues.csv" % [clue.id, key])
	return errors


## Returns the problem, if any, of the candidate [param counts] of generated dossiers: fewer than
## MIN_PERCENT_WITHIN percent within [param params] min_candidates..max_candidates, or none.
static func check_candidates(counts: Array[int], params: ClueSetParams) -> Array[String]:
	if counts.is_empty():
		return ["no dossiers were generated"]
	var within: int = counts.filter(func(n: int) -> bool: return is_within(n, params)).size()
	if within * 100 >= counts.size() * MIN_PERCENT_WITHIN:
		return []
	var bad: Array[int] = counts.filter(func(n: int) -> bool: return not is_within(n, params))
	bad.sort()
	return [
		(
			"only %d of %d dossiers leave %d..%d candidates, expected %d%%; the others leave %s"
			% [
				within,
				counts.size(),
				params.min_candidates,
				params.max_candidates,
				MIN_PERCENT_WITHIN,
				bad
			]
		)
	]


## True when [param count] candidates is within the limits of [param params].
static func is_within(count: int, params: ClueSetParams) -> bool:
	return count >= params.min_candidates and count <= params.max_candidates
