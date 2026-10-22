class_name LinkLayer
extends Control
## Draws the links between cards as strings across the corkboard: one straight line for each
## pair of points it is given. It sits under the cards and ignores the mouse. The line colour
## is the theme item `link_color` of theme type `LinkLayer`, falling back to the Label's
## `font_color`.
## Bible: gate-and-address-spec.md#player-tools

## Theme type of this control's colour item.
const THEME_TYPE: StringName = &"LinkLayer"
## Width of a string, in board pixels.
const LINE_WIDTH: float = 2.0

var _segments: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var color: Color = get_theme_color(&"font_color", &"Label")
	if has_theme_color(&"link_color", THEME_TYPE):
		color = get_theme_color(&"link_color", THEME_TYPE)
	for index: int in range(0, _segments.size() - 1, 2):
		draw_line(_segments[index], _segments[index + 1], color, LINE_WIDTH, true)


## Replaces the lines: [param segments] holds the two ends of each line in turn.
func set_segments(segments: PackedVector2Array) -> void:
	_segments = segments
	queue_redraw()


## Returns the two ends of each line in turn.
func get_segments() -> PackedVector2Array:
	return _segments


## Returns the two ends of the string of each link between visible [param cards], card centre
## to card centre, each link once, whichever of the two notes holds it.
static func segments_for(
	cards: Dictionary[StringName, ClueCard], intel: IntelState
) -> PackedVector2Array:
	var segments: PackedVector2Array = PackedVector2Array()
	var drawn: Dictionary[String, bool] = {}
	for clue_id: StringName in cards:
		for other_id: StringName in intel.note_for(clue_id).links:
			var pair: String = _pair_key(clue_id, other_id)
			if drawn.has(pair) or not cards.has(other_id):
				continue
			drawn[pair] = true
			if cards[clue_id].visible and cards[other_id].visible:
				segments.append(cards[clue_id].position + cards[clue_id].size / 2.0)
				segments.append(cards[other_id].position + cards[other_id].size / 2.0)
	return segments


static func _pair_key(first: StringName, second: StringName) -> String:
	if String(first) < String(second):
		return "%s|%s" % [first, second]
	return "%s|%s" % [second, first]
