class_name FundsSparkline
extends Control
## The Command tab's 30-day balance sparkline (docs/content/m27-daily-rhythm.md section 4):
## one drawn bar per daily balance, oldest on the left, scaled between the lowest and highest
## balance (and zero); a balance below zero is red. Drawn, not glyphs, since the font has no
## block characters.
## Bible: docs/content/m27-daily-rhythm.md section 4

## Bar slots drawn (one per kept balance).
const SLOTS: int = ConfidenceRules.FUNDS_HISTORY_KEPT
## Width of one slot and the gap inside it, in pixels.
const SLOT_WIDTH: float = 12.0
const GAP: float = 3.0
const BAR_COLOR: Color = UiPalette.GOOD
const NEGATIVE_COLOR: Color = UiPalette.ALARM

var _balances: Array[int] = []


func _init() -> void:
	custom_minimum_size = Vector2(SLOTS * SLOT_WIDTH, CommandRow.HEIGHT)
	mouse_filter = MOUSE_FILTER_IGNORE


## Shows [param balances] ($k, oldest first; the last [constant SLOTS]).
func show_balances(balances: Array[int]) -> void:
	_balances = balances.slice(maxi(0, balances.size() - SLOTS))
	queue_redraw()


## Returns the balances drawn, oldest first.
func get_balances() -> Array[int]:
	return _balances.duplicate()


## The bar rectangles for the balances, in the control's coordinates, for [param area].
static func bars(balances: Array[int], area: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if balances.is_empty():
		return out
	var lowest: int = balances.min()
	var highest: int = balances.max()
	var low: int = mini(0, lowest)
	var high: int = maxi(0, highest)
	var span: float = maxf(1.0, float(high - low))
	var inner: float = area.y - 4.0
	var zero_y: float = 2.0 + inner * (high / span)
	for index: int in balances.size():
		var y: float = 2.0 + inner * ((high - balances[index]) / span)
		var top: float = minf(y, zero_y)
		var height: float = maxf(1.0, absf(zero_y - y))
		out.append(Rect2(index * SLOT_WIDTH, top, SLOT_WIDTH - GAP, height))
	return out


func _draw() -> void:
	var rects: Array[Rect2] = bars(_balances, size)
	for index: int in rects.size():
		draw_rect(rects[index], NEGATIVE_COLOR if _balances[index] < 0 else BAR_COLOR)
