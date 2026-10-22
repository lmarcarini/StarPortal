extends RefCounted
## Test fixture for the Analysis Board: five hand-made clues, one of each kind, whose texts
## are fixture templates registered in a test-only translation, and helpers to build
## simulations and clue-only states of any size.

const SOURCE_KEY: StringName = &"TEST_SOURCE_ONE"
const TEXT_KEYS: Array[StringName] = [
	&"TEST_TEXT_FRAGMENT",
	&"TEST_TEXT_PICTORIAL",
	&"TEST_TEXT_SKY_CHART",
	&"TEST_TEXT_ORDINAL",
	&"TEST_TEXT_NEIGHBOUR",
]
const TEMPLATES: Dictionary[String, String] = {
	"TEST_SOURCE_ONE": "Test Source",
	"TEST_TEXT_FRAGMENT": "Glyph {glyph_a} at seal {seal_a}",
	"TEST_TEXT_PICTORIAL": "A sketch: {picture_a}",
	"TEST_TEXT_SKY_CHART": "Sky of {world}: {count} stars",
	"TEST_TEXT_ORDINAL": "Seal {seal_a} holds {glyph_a}",
	"TEST_TEXT_NEIGHBOUR": "{glyph_a} sits next to {glyph_b}",
}
const ARGS: Array[Dictionary] = [
	{"glyph_a": 0, "seal_a": 2},
	{"picture_a": 0},
	{"world": "P3X-118", "count": 7},
	{"seal_a": 3, "glyph_a": 1},
	{"glyph_a": 0, "glyph_b": 1},
]
const IMAGES: Array[Array] = [[], [5], [14, 3, 22, 7, 30, 1, 9], [], []]


## Installs the test translation; pair with [method remove_translation].
static func add_translation() -> Translation:
	var translation: Translation = Translation.new()
	translation.locale = "en"
	for key: String in TEMPLATES:
		translation.add_message(key, TEMPLATES[key])
	TranslationServer.add_translation(translation)
	return translation


## Removes [param translation] installed by [method add_translation].
static func remove_translation(translation: Translation) -> void:
	TranslationServer.remove_translation(translation)


## Returns a hand-made clue number [param number] (1-based); kind and text follow
## (number - 1) modulo 5, the grade is (number - 1) modulo 5 too.
static func clue(number: int) -> ClueRecord:
	var slot: int = (number - 1) % TEXT_KEYS.size()
	var record: ClueRecord = ClueRecord.new()
	record.id = StringName("clue_%04d" % number)
	record.kind = slot as ClueRecord.Kind
	record.dossier_id = &"dossier_0001"
	record.target_world_id = &"world_secret"
	record.source_key = SOURCE_KEY
	record.grade = slot
	record.text_key = TEXT_KEYS[slot]
	record.text_args = ARGS[slot].duplicate()
	var glyphs: Array[int] = []
	glyphs.assign(IMAGES[slot])
	record.image_glyphs = glyphs
	record.received_tick = 1440 * number
	return record


## Returns a new game holding [param count] clues, numbered from 1, and no notes.
static func state(count: int) -> GameState:
	var result: GameState = GameState.new_game(777)
	for number: int in range(1, count + 1):
		result.intel.add_clue(clue(number))
	result.intel.next_clue_number = count + 1
	result.clock.tick = 1440 * (count + 1)
	return result


## Returns a simulation over [param game_state], bound to the EventBus.
static func simulation(game_state: GameState) -> Simulation:
	var result: Simulation = Simulation.new(game_state)
	EventBus.bind_simulation(result)
	return result
