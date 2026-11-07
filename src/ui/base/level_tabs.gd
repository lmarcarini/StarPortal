class_name LevelTabs
extends VBoxContainer
## The level column of the Base tab: one toggle per level, the shown one pressed; a level
## still being dug shows how far the dig has come ("L4 45%"). Under them, the next level that
## can be dug shows as a ghost tab, "L2 +", greyed while research still locks it; pressing it
## asks for the dig (the palette's Dig entry holds to dig).
## Bible: docs/content/m2-base.md section 6

## Emitted when the player picks level [param number] (1 the top one).
signal level_chosen(number: int)
## Emitted when the player presses the ghost tab of the next level.
signal dig_chosen

## The ghost tab of the next level to dig; hidden when there is none.
var next_tab: Button = Button.new()

var _group: ButtonGroup = ButtonGroup.new()
var _levels: Array[LevelState] = []
var _shown: int = 1
var _dig: SiteProgress = SiteProgress.new()
var _next: int = 0


func _init() -> void:
	next_tab.focus_mode = FOCUS_NONE
	next_tab.flat = true
	next_tab.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	next_tab.visible = false
	next_tab.pressed.connect(dig_chosen.emit)
	add_child(next_tab)


## Rebuilds the column for [param levels], with level [param shown] pressed.
func show_levels(levels: Array[LevelState], shown: int) -> void:
	_levels = levels
	_shown = shown
	for child: Node in get_children():
		if child != next_tab:
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
	move_child(next_tab, -1)
	refresh()


## Returns how many level tabs there are, not counting the ghost tab.
func level_count() -> int:
	return get_child_count() - 1


## Shows the ghost tab of level [param number] ("L2 +"; 0 hides it), enabled when
## [param allowed], with [param reason] as its tooltip.
func show_next(number: int, allowed: bool, reason: String) -> void:
	_next = number
	next_tab.visible = number > 0
	next_tab.disabled = not allowed
	next_tab.tooltip_text = reason
	_label_next()


## Marks level [param number] as the shown one.
func mark(number: int) -> void:
	_shown = number
	refresh()


## Keeps [param progress] (SiteProgress.of_dig) for the level being dug; [method refresh]
## shows it.
func show_dig(progress: SiteProgress) -> void:
	_dig = progress


## Rewrites the labels: the progress of a level being dug, and which level is shown.
func refresh() -> void:
	_label_next()
	for index: int in level_count():
		var button: Button = get_child(index) as Button
		button.text = label_for(_levels[index], index + 1, _dig)
		button.set_pressed_no_signal(index + 1 == _shown)


## Returns the label of [param level] numbered [param number]: "L3", or "L4 45%" while dug,
## from the dig's [param progress].
static func label_for(level: LevelState, number: int, progress: SiteProgress = null) -> String:
	if level.is_dug():
		return TranslationServer.translate(&"BASE_LEVEL_SHORT").format({"n": number})
	var pct: int = 0 if progress == null else ProgressText.percent(progress)
	var text: String = TranslationServer.translate(&"BASE_LEVEL_DIGGING")
	return text.format({"n": number, "pct": pct})


## True when there is a next level to dig (its ghost tab shows in the Build sub-tab).
func has_next() -> bool:
	return _next > 0


func _label_next() -> void:
	next_tab.text = tr(&"BASE_LEVEL_NEXT").format({"n": _next})


func _on_pressed(number: int) -> void:
	_shown = number
	level_chosen.emit(number)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _levels.is_empty():
		refresh()
