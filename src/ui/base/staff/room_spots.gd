class_name RoomSpots
extends RefCounted
## Where staff tokens stand inside a room: spots as fractions of the room's floor (0..1 on
## each axis), spread in a grid clear of the label strip at the top, one per slot. Pure.
## Bible: docs/content/interface-pass.md section 5 (Staff tokens)

## Fraction of the room's height kept clear at the top for the name label.
const LABEL_STRIP: float = 0.3


## [param slot_count] spots (at least one) for a room of [param _room_def] that is
## [param size] cells, as fractions of its floor.
static func for_room(_room_def: RoomDef, size: Vector2i, slot_count: int) -> Array[Vector2]:
	var count: int = maxi(slot_count, 1)
	var aspect: float = float(maxi(size.x, 1)) / float(maxi(size.y, 1))
	var columns: int = clampi(ceili(sqrt(count * aspect)), 1, count)
	var rows: int = ceili(float(count) / columns)
	var spots: Array[Vector2] = []
	for index: int in count:
		var column: int = index % columns
		var row: int = index / columns
		var x: float = (column + 0.5) / columns
		var y: float = LABEL_STRIP + (row + 0.5) / rows * (1.0 - LABEL_STRIP)
		spots.append(Vector2(lerpf(0.12, 0.88, x), minf(y, 0.9)))
	return spots
