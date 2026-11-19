class_name TrayArrow
extends RefKey
## The small arrow key at the right end of a console tray strip that scrolls (owner request
## after M6-03): shown while there is more to the right, a press scrolls one card on.
## Bible: docs/content/interface-reference.md section 8

## Pixels one press scrolls (a card and its gap).
const STEP: int = 114

var _scroll: ScrollContainer = null


## Watches [param scroll]; sits over its right end.
func attach(scroll: ScrollContainer) -> void:
	_scroll = scroll
	icon_id = &"arrow"
	name = "TrayArrow"
	z_index = 2
	pressed.connect(func() -> void: _scroll.scroll_horizontal += STEP)
	scroll.get_parent().add_child(self)


func _process(_delta: float) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		visible = false
		return
	var bar: HScrollBar = _scroll.get_h_scroll_bar()
	visible = bar.max_value - bar.page > 1.0 and bar.value < bar.max_value - bar.page - 1.0
	size = Vector2(28, minf(_scroll.size.y - 16.0, 112.0))
	global_position = _scroll.global_position + Vector2(_scroll.size.x - size.x, 8)
