class_name PortraitMask
extends RefCounted
## A 96×96 boolean mask for the portrait painter, stored as bit rows so that the shading
## steps (union, intersection, shifts by a few pixels) cost one integer operation per row
## instead of one per pixel. Each row is two 48-bit words: x 0..47 in the low word, x 48..95
## in the high word. Pixels outside the canvas are never set.
## Bible: docs/content/portraits.md ("Style")

## Canvas side, in pixels.
const SIZE: int = 96
## Bits per word.
const WORD: int = 48
## All 48 bits of a word set.
const FULL: int = (1 << 48) - 1

## Two words per row, row y at 2y (low) and 2y + 1 (high).
var rows: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	rows.resize(SIZE * 2)


## An ellipse centred on ([param cx], [param cy]) with radii [param rx], [param ry]: the
## pixels where ((x - cx) / rx)² + ((y - cy) / ry)² ≤ 1.
static func ellipse(cx: float, cy: float, rx: float, ry: float) -> PortraitMask:
	var mask := PortraitMask.new()
	if rx <= 0.0 or ry <= 0.0:
		return mask
	for y: int in range(maxi(0, ceili(cy - ry)), mini(SIZE - 1, floori(cy + ry)) + 1):
		var t: float = 1.0 - pow((y - cy) / ry, 2.0)
		if t < 0.0:
			continue
		var half: float = rx * sqrt(t)
		mask.set_span(y, ceili(cx - half - 0.000001), floori(cx + half + 0.000001))
	return mask


## The pixels from ([param x0], [param y0]) to ([param x1], [param y1]), both included.
static func rect(x0: int, y0: int, x1: int, y1: int) -> PortraitMask:
	var mask := PortraitMask.new()
	for y: int in range(maxi(0, y0), mini(SIZE - 1, y1) + 1):
		mask.set_span(y, x0, x1)
	return mask


## A filled polygon through [param points] (scanline fill; edges included, as in the
## prototype's PIL polygon).
static func poly(points: Array[Vector2i]) -> PortraitMask:
	var mask := PortraitMask.new()
	var low: int = points[0].y
	var high: int = points[0].y
	for point: Vector2i in points:
		low = mini(low, point.y)
		high = maxi(high, point.y)
	for y: int in range(maxi(0, low), mini(SIZE - 1, high) + 1):
		var sample: float = clampf(y, low + 0.001, high - 0.001)
		var crossings: Array[float] = _crossings(points, sample)
		for i: int in range(0, crossings.size() - 1, 2):
			mask.set_span(y, roundi(crossings[i]), roundi(crossings[i + 1]))
	return mask


## The pixels above the line y = [param top] + floor([param slope] × |x − [param cx]|): a
## hairline that rises toward the middle.
static func above_v(cx: int, top: int, slope: float) -> PortraitMask:
	var mask := PortraitMask.new()
	for y: int in SIZE:
		var need: int = y - top + 1
		if need <= 0:
			mask.set_span(y, 0, SIZE - 1)
			continue
		var reach: int = ceili(need / slope - 0.000001)
		mask.set_span(y, 0, cx - reach)
		mask.set_span(y, cx + reach, SIZE - 1)
	return mask


## The rows [param y0] to [param y1] (all columns).
static func band(y0: int, y1: int) -> PortraitMask:
	return rect(0, y0, SIZE - 1, y1)


## The columns where |x − [param cx]| is more than [param reach] (all rows when [param rows_to]
## is SIZE; else rows 0 to [param rows_to]).
static func outside(cx: int, reach: int, rows_to: int = SIZE) -> PortraitMask:
	var mask := PortraitMask.new()
	for y: int in range(0, mini(SIZE - 1, rows_to) + 1):
		mask.set_span(y, 0, cx - reach - 1)
		mask.set_span(y, cx + reach + 1, SIZE - 1)
	return mask


## Sets x0..x1 on row [param y] (clipped to the canvas).
func set_span(y: int, x0: int, x1: int) -> void:
	if y < 0 or y >= SIZE:
		return
	var a: int = maxi(0, x0)
	var b: int = mini(SIZE - 1, x1)
	if a > b:
		return
	rows[y * 2] |= span_bits(a, b, 0)
	rows[y * 2 + 1] |= span_bits(a, b, WORD)


## True when ([param x], [param y]) is set.
func has(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return false
	var word: int = rows[y * 2 + x / WORD]
	return (word >> (x % WORD)) & 1 == 1


## True when nothing is set.
func is_empty() -> bool:
	for word: int in rows:
		if word != 0:
			return false
	return true


## A new mask: this or [param other].
func union(other: PortraitMask) -> PortraitMask:
	var out := PortraitMask.new()
	for i: int in SIZE * 2:
		out.rows[i] = rows[i] | other.rows[i]
	return out


## A new mask: this and [param other].
func intersect(other: PortraitMask) -> PortraitMask:
	var out := PortraitMask.new()
	for i: int in SIZE * 2:
		out.rows[i] = rows[i] & other.rows[i]
	return out


## A new mask: this and not [param other].
func minus(other: PortraitMask) -> PortraitMask:
	var out := PortraitMask.new()
	for i: int in SIZE * 2:
		out.rows[i] = rows[i] & (FULL ^ other.rows[i])
	return out


## Word [param half] (0 low, 1 high) of row [param y] seen moved so that pixel x holds what
## this mask has at (x + [param dx], y + [param dy]); off-canvas reads are unset. [param dx]
## is −47..47.
func shifted_word(y: int, dx: int, dy: int, half: int) -> int:
	var source: int = y + dy
	if source < 0 or source >= SIZE:
		return 0
	var lo: int = rows[source * 2]
	var hi: int = rows[source * 2 + 1]
	if dx > 0:
		return ((lo >> dx) | (hi << (WORD - dx))) & FULL if half == 0 else hi >> dx
	if dx < 0:
		var d: int = -dx
		return (lo << d) & FULL if half == 0 else ((hi << d) | (lo >> (WORD - d))) & FULL
	return lo if half == 0 else hi


## The leftmost and rightmost set columns, or (-1, -1) when empty.
func column_range() -> Vector2i:
	var lo: int = 0
	var hi: int = 0
	for y: int in SIZE:
		lo |= rows[y * 2]
		hi |= rows[y * 2 + 1]
	var both: Array[int] = [lo, hi]
	var first: int = -1
	var last: int = -1
	for x: int in SIZE:
		if (both[x / WORD] >> (x % WORD)) & 1 == 1:
			first = x if first < 0 else first
			last = x
	return Vector2i(first, last)


## The bits of columns [param x0]..[param x1] that fall in the word starting at column
## [param base] (0 or 48).
static func span_bits(x0: int, x1: int, base: int) -> int:
	var a: int = maxi(x0, base) - base
	var b: int = mini(x1, base + WORD - 1) - base
	if a > b:
		return 0
	return ((1 << (b - a + 1)) - 1) << a


static func _crossings(points: Array[Vector2i], y: float) -> Array[float]:
	var found: Array[float] = []
	for i: int in points.size():
		var a: Vector2i = points[i]
		var b: Vector2i = points[(i + 1) % points.size()]
		if a.y == b.y or y < mini(a.y, b.y) or y >= maxi(a.y, b.y):
			continue
		found.append(a.x + (y - a.y) * float(b.x - a.x) / float(b.y - a.y))
	found.sort()
	return found
