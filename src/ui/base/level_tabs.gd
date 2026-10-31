class_name LevelTabs
extends VBoxContainer
## The level column of the Base tab: one toggle per level, the shown one pressed; a level
## still being dug shows its days left ("L4 ~20d").
## Bible: docs/content/m2-base.md section 6

## Emitted when the player picks level [param number] (1 the top one).
signal level_chosen(number: int)

var _group: ButtonGroup = ButtonGroup.new()
var _levels: Array[LevelState] = []
var _shown: int = 1


## Rebuilds the column for [param levels], with level [param shown] pressed.
func show_levels(levels: Array[LevelState], shown: int) -> void:
	_levels = levels
	_shown = shown
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for index: int in levels.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = FOCUS_NONE
		button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_on_pressed.bind(index + 1))
		add_child(button)
	refresh()


## Marks level [param number] as the shown one.
func mark(number: int) -> void:
	_shown = number
	refresh()


## Rewrites the labels: days left of a level being dug, and which level is shown.
func refresh() -> void:
	for index: int in get_child_count():
		var button: Button = get_child(index) as Button
		button.text = label_for(_levels[index], index + 1)
		button.set_pressed_no_signal(index + 1 == _shown)


## Returns the label of [param level] numbered [param number]: "L3", or "L4 ~20d" while dug.
static func label_for(level: LevelState, number: int) -> String:
	if level.is_dug():
		return TranslationServer.translate(&"BASE_LEVEL_SHORT").format({"n": number})
	var days: int = ceili(float(level.dig_ticks_left) / TimeMath.TICKS_PER_DAY)
	var text: String = TranslationServer.translate(&"BASE_LEVEL_DIGGING")
	return text.format({"n": number, "days": days})


func _on_pressed(number: int) -> void:
	_shown = number
	level_chosen.emit(number)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _levels.is_empty():
		refresh()
