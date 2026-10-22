class_name ClueCommon
extends RefCounted
## Shared helpers of the clue kinds: the record every kind returns, source and grade choice,
## text variant choice and a seeded shuffle.
## Bible: gate-and-address-spec.md#clue-types-and-reliability

## Source keys, and the grade the analyst shows for each (0..4 = A..E), in the same order.
const SOURCE_KEYS: Array[StringName] = [
	&"CLUE_SOURCE_DIRECTORATE",
	&"CLUE_SOURCE_ARCHIVE_1961",
	&"CLUE_SOURCE_SIGINT",
	&"CLUE_SOURCE_ACADEMIC",
]
const SOURCE_GRADES: Array[int] = [1, 2, 1, 0]
## Suffixes of the text variants of every kind.
const VARIANTS: Array[String] = ["A", "B"]


## Returns a true clue of [param kind] with a random source and its grade. [param text_key] is
## the key without its variant suffix; one variant is picked. The caller sets id, dossier_id and
## received_tick.
static func make_record(
	context: ClueContext,
	kind: ClueRecord.Kind,
	constraints: Array[AddressConstraint],
	text: Dictionary
) -> ClueRecord:
	var record := ClueRecord.new()
	record.kind = kind
	record.target_world_id = context.target_id
	record.constraints = constraints
	record.is_true = true
	var source: int = context.rng.randi_range(0, SOURCE_KEYS.size() - 1)
	record.source_key = SOURCE_KEYS[source]
	record.grade = SOURCE_GRADES[source]
	var variant: String = VARIANTS[context.rng.randi_range(0, VARIANTS.size() - 1)]
	record.text_key = StringName("%s_%s" % [text["key"], variant])
	record.text_args = text.get("args", {})
	return record


## A Fisher-Yates shuffle of a copy of [param values] driven by [param rng]; Array's built-in
## shuffle would draw from the global generator.
static func shuffled(rng: RandomNumberGenerator, values: Array[int]) -> Array[int]:
	var result: Array[int] = values.duplicate()
	for index: int in range(result.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: int = result[index]
		result[index] = result[other]
		result[other] = swap
	return result


## Returns [param count] distinct seals from 1..7 in a random choice, sorted ascending.
static func random_seals(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var seals: Array[int] = []
	for seal: int in range(1, GateAddress.COORDINATE_COUNT + 1):
		seals.append(seal)
	var picked: Array[int] = shuffled(rng, seals).slice(0, count)
	picked.sort()
	return picked
