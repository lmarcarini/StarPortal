class_name PlanLabel
extends RefCounted
## Fits a room's name label inside its floor on the base plan, so no label silently
## disappears: one line at the normal size, else the words wrapped onto lines, else a smaller
## size, and only as a last resort the last line cut with "…". Pure layout; the painter draws.
## Bible: docs/content/m2-base.md section 6 (every room labelled, in both languages)

## Normal and smallest label sizes, in plan pixels.
const SIZE: int = 11
const MIN_SIZE: int = 8
const ELLIPSIS: String = "…"
## Gap between the label and the room's wall, in plan pixels.
const INSET: float = 3.0


## The lines and size that fit [param text] in [param area] with [param font]:
## {"lines": Array[String], "size": int}. "lines" is empty only for an empty text or an area
## too small for one line at [constant MIN_SIZE].
static func fit(text: String, area: Vector2, font: Font) -> Dictionary:
	var room: Vector2 = area - Vector2.ONE * INSET * 2.0
	if text.is_empty() or room.y < MIN_SIZE:
		return {"lines": [] as Array[String], "size": SIZE}
	for size: int in range(SIZE, MIN_SIZE - 1, -1):
		var max_lines: int = maxi(1, floori(room.y / line_height(size)))
		var lines: Array[String] = wrap_words(text, room.x, font, size)
		if lines.size() <= max_lines and _widest(lines, font, size) <= room.x:
			return {"lines": lines, "size": size}
	return {"lines": _cut(text, room, font), "size": MIN_SIZE}


## Height of one label line at [param size].
static func line_height(size: int) -> float:
	return size + 2.0


## [param text] split at spaces into lines no wider than [param width] where the words allow.
static func wrap_words(text: String, width: float, font: Font, size: int) -> Array[String]:
	var lines: Array[String] = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var joined: String = word if line.is_empty() else line + " " + word
		if line.is_empty() or _width(joined, font, size) <= width:
			line = joined
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines


## The last resort at [constant MIN_SIZE]: as many wrapped lines as fit, the last one cut
## with an ellipsis until it fits.
static func _cut(text: String, room: Vector2, font: Font) -> Array[String]:
	var max_lines: int = maxi(1, floori(room.y / line_height(MIN_SIZE)))
	var lines: Array[String] = wrap_words(text, room.x, font, MIN_SIZE)
	if lines.size() > max_lines:
		lines.resize(max_lines)
		lines[max_lines - 1] += ELLIPSIS
	for index: int in lines.size():
		var line: String = lines[index]
		while line.length() > 1 and _width(line, font, MIN_SIZE) > room.x:
			line = line.trim_suffix(ELLIPSIS)
			line = line.substr(0, line.length() - 1) + ELLIPSIS
		lines[index] = line
	return lines


static func _widest(lines: Array[String], font: Font, size: int) -> float:
	var widest: float = 0.0
	for line: String in lines:
		widest = maxf(widest, _width(line, font, size))
	return widest


static func _width(text: String, font: Font, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
