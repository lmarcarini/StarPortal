class_name BoardLayout
extends RefCounted
## Where the cards of the Analysis Board sit. Pure and static. A card with a saved position
## keeps it; the others take the next free grid cell in arrival order. A saved position of
## (0, 0) means "no position", so a card the player drops is kept off the origin.
## Bible: gate-and-address-spec.md#player-tools

## Size of a card, in board pixels.
const CARD_SIZE: Vector2i = Vector2i(240, 260)
## Space between grid cells.
const GAP: Vector2i = Vector2i(16, 16)
## Space between the board edge and the first grid cell.
const MARGIN: Vector2i = Vector2i(16, 16)
## Grid cells per row.
const COLUMNS: int = 5
## Smallest coordinate of a card the player placed.
const MIN_COORDINATE: int = 8
## Distance a gamepad nudge moves a card.
const NUDGE_STEP: int = 16


## True when [param note] holds a position the player gave the card.
static func is_placed(note: ClueNote) -> bool:
	return note.board_position != Vector2i.ZERO


## Returns the top-left corner of grid cell [param index], counting along the rows.
static func cell_origin(index: int) -> Vector2i:
	var cell: Vector2i = Vector2i(index % COLUMNS, floori(float(index) / COLUMNS))
	return MARGIN + cell * (CARD_SIZE + GAP)


## Returns [param position] kept on the board and off the origin.
static func clamp_position(position: Vector2i) -> Vector2i:
	var most: int = ClueNote.MAX_BOARD_COORDINATE
	return Vector2i(
		clampi(position.x, MIN_COORDINATE, most), clampi(position.y, MIN_COORDINATE, most)
	)


## Returns the top-left corner of every clue of [param intel], by clue id.
static func positions(intel: IntelState) -> Dictionary[StringName, Vector2i]:
	var result: Dictionary[StringName, Vector2i] = {}
	var taken: Array[Rect2i] = []
	for clue: ClueRecord in intel.clues:
		var note: ClueNote = intel.note_for(clue.id)
		if is_placed(note):
			result[clue.id] = note.board_position
			taken.append(Rect2i(note.board_position, CARD_SIZE))
	for clue: ClueRecord in intel.clues:
		if result.has(clue.id):
			continue
		var origin: Vector2i = _first_free_cell(taken)
		result[clue.id] = origin
		taken.append(Rect2i(origin, CARD_SIZE))
	return result


## Returns the size the board needs to hold every card at [param positions], plus a margin.
static func content_size(positions_by_id: Dictionary[StringName, Vector2i]) -> Vector2i:
	var size: Vector2i = Vector2i.ZERO
	for position: Vector2i in positions_by_id.values():
		size = size.max(position + CARD_SIZE)
	return size + MARGIN


static func _first_free_cell(taken: Array[Rect2i]) -> Vector2i:
	var index: int = 0
	while _is_taken(index, taken):
		index += 1
	return cell_origin(index)


static func _is_taken(index: int, taken: Array[Rect2i]) -> bool:
	var cell: Rect2i = Rect2i(cell_origin(index), CARD_SIZE)
	return taken.any(func(other: Rect2i) -> bool: return other.intersects(cell))
