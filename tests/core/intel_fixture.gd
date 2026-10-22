extends RefCounted
## Test fixture for intel and Workbench state: sample clues of different kinds with
## constraints and text arguments, notes with links and tags, and a five-constraint draft.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#player-tools

const FRAGMENT_ID: StringName = &"clue_0001"
const SKY_CHART_ID: StringName = &"clue_0002"
const CLOCK_TICK: int = 1000


## A fragment clue: two glyphs at seals, with glyph and seal text arguments.
static func fragment(id: StringName = FRAGMENT_ID) -> ClueRecord:
	var record := ClueRecord.new()
	record.id = id
	record.kind = ClueRecord.Kind.FRAGMENT
	record.dossier_id = &"dossier_0001"
	record.target_world_id = &"world_p3x_118"
	record.constraints.append(AddressConstraint.glyph_at(2, 14))
	record.constraints.append(AddressConstraint.glyph_at(5, 3))
	record.source_key = &"CLUE_SOURCE_DIRECTORATE"
	record.grade = 1
	record.text_key = &"CLUE_TEXT_FRAGMENT_TWO"
	record.text_args = {"glyph_a": 14, "seal_a": 2, "glyph_b": 3, "seal_b": 5}
	record.received_tick = 400
	return record


## A sky chart clue: the seven anchors as an unordered set, drawn as an image.
static func sky_chart(id: StringName = SKY_CHART_ID) -> ClueRecord:
	var record := ClueRecord.new()
	record.id = id
	record.kind = ClueRecord.Kind.SKY_CHART
	record.dossier_id = &"dossier_0002"
	record.target_world_id = &"world_p3x_118"
	var anchors: Array[int] = [14, 3, 22, 7, 30, 1, 9]
	record.constraints.append(AddressConstraint.exact_set(anchors))
	record.source_key = &"CLUE_SOURCE_MOTH"
	record.grade = 4
	record.text_key = &"CLUE_TEXT_SKY_CHART"
	record.text_args = {"world": "P3X-118", "count": 7}
	record.image_glyphs = anchors.duplicate()
	record.received_tick = 900
	return record


## A note with [param links] and [param tags], suspect, at (120, 3400).
static func note(links: Array[StringName], tags: Array[String]) -> ClueNote:
	var result := ClueNote.new()
	result.is_suspect = true
	result.links = links.duplicate()
	result.tags = tags.duplicate()
	result.board_position = Vector2i(120, 3400)
	return result


## Five Workbench constraints of different kinds.
static func five_constraints() -> Array[AddressConstraint]:
	var anchors: Array[int] = [14, 3, 22, 7, 30, 1, 9]
	return [
		AddressConstraint.glyph_at(2, 14),
		AddressConstraint.glyph_not_at(1, 3),
		AddressConstraint.excluded(35),
		AddressConstraint.exact_set(anchors),
		AddressConstraint.nearer_than(14, 22),
	]


## A state at clock tick CLOCK_TICK with both sample clues, a note on each linking to the
## other, the counters moved on, a scheduled dossier and a five-constraint draft at origin 30.
static func state() -> GameState:
	var result := GameState.new_game(4242)
	result.clock.tick = CLOCK_TICK
	result.intel.add_clue(fragment())
	result.intel.add_clue(sky_chart())
	var to_sky: Array[StringName] = [SKY_CHART_ID]
	var to_fragment: Array[StringName] = [FRAGMENT_ID]
	var tags: Array[String] = ["P3X-118", "Heron?"]
	var other_tags: Array[String] = ["ÁGUA"]
	result.intel.notes[FRAGMENT_ID] = note(to_sky, tags)
	result.intel.notes[SKY_CHART_ID] = note(to_fragment, other_tags)
	result.intel.next_clue_number = 3
	result.intel.next_dossier_number = 3
	result.intel.scheduled_dossiers[&"world_abydos"] = 5000
	result.workbench.origin_glyph = 30
	result.workbench.constraints = five_constraints()
	return result
