class_name LevelTabs
extends Control
## The Base's level keys (interface-reference.md section 8, base_levels and base_dig): L1 to L4
## as 56 x 52 keys 8 px apart (the shown level amber, dug levels steel, undug ones off; a
## level being dug reads "L4 45%"), and the DIG key right under them, 56 x 88 with a down
## arrow, the next level and its cost on a dim line below. Pressing DIG asks for the dig
## ([signal dig_chosen]; the view submits the same command as the Build palette's Dig).
## Bible: docs/content/interface-reference.md section 8

## Emitted when the player picks level [param number] (1 the top one).
signal level_chosen(number: int)
## Emitted when the player presses DIG.
signal dig_chosen

## Levels shown as keys, dug or not.
const SHOWN: int = 4
## Key size and pitch, in pixels; where DIG starts (below the level keys).
const KEY: Vector2 = Vector2(56, 52)
const PITCH: float = 60.0
const DIG_TOP: float = 252.0
const DIG_SIZE: Vector2 = Vector2(56, 88)

## The DIG key; disabled while no dig is allowed.
var next_tab: RefKey = RefKey.new()

var _keys: Array[RefKey] = []
var _levels: Array[LevelState] = []
var _shown: int = 1
var _dig: SiteProgress = SiteProgress.new()
var _next: int = 0
var _cost: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in SHOWN:
		var key: RefKey = RefKey.new()
		key.name = "Level%d" % (index + 1)
		key.position = Vector2(4, index * PITCH)
		key.size = KEY
		key.label_size = 22
		key.focus_mode = Control.FOCUS_NONE
		key.pressed.connect(_on_pressed.bind(index + 1))
		add_child(key)
		_keys.append(key)
	next_tab.name = "Dig"
	next_tab.icon_id = &"down"
	next_tab.label = "BASE_DIG"
	next_tab.label_size = 16
	next_tab.position = Vector2(4, DIG_TOP)
	next_tab.size = DIG_SIZE
	next_tab.pressed.connect(dig_chosen.emit)
	add_child(next_tab)


## Shows [param levels], with level [param shown] the current one.
func show_levels(levels: Array[LevelState], shown: int) -> void:
	_levels = levels
	_shown = shown
	refresh()


## How many levels exist (dug or being dug).
func level_count() -> int:
	return _levels.size()


## Shows the next level [param number] to dig (0: none) and whether DIG is [param allowed];
## [param reason] is its hover reason. [param cost] is the line under DIG.
func show_next(number: int, allowed: bool, reason: String, cost: String = "") -> void:
	_next = number
	_cost = cost
	next_tab.disabled = not allowed
	next_tab.tooltip_text = reason
	queue_redraw()


## Marks level [param number] as the shown one.
func mark(number: int) -> void:
	_shown = number
	refresh()


## Keeps [param progress] (SiteProgress.of_dig) for the level being dug.
func show_dig(progress: SiteProgress) -> void:
	_dig = progress


## Rewrites the keys: labels, the shown level, dug and undug.
func refresh() -> void:
	for index: int in SHOWN:
		var key: RefKey = _keys[index]
		var exists: bool = index < _levels.size()
		key.label = (
			label_for(_levels[index], index + 1, _dig)
			if exists
			else TranslationServer.translate(&"BASE_LEVEL_SHORT").format({"n": index + 1})
		)
		key.disabled = not exists or not _levels[index].is_dug()
		key.style = RefPaint.KeyStyle.AMBER if index + 1 == _shown else RefPaint.KeyStyle.STEEL
	queue_redraw()


## The key of level [param number].
func get_key(number: int) -> RefKey:
	return _keys[number - 1]


## Returns the label of [param level] numbered [param number]: "L3", or "L4 45%" while dug.
static func label_for(level: LevelState, number: int, progress: SiteProgress = null) -> String:
	if level.is_dug():
		return TranslationServer.translate(&"BASE_LEVEL_SHORT").format({"n": number})
	var pct: int = 0 if progress == null else ProgressText.percent(progress)
	var text: String = TranslationServer.translate(&"BASE_LEVEL_DIGGING")
	return text.format({"n": number, "pct": pct})


## True when there is a next level to dig.
func has_next() -> bool:
	return _next > 0


func _on_pressed(number: int) -> void:
	_shown = number
	level_chosen.emit(number)
	refresh()


func _draw() -> void:
	if _next <= 0:
		return
	var line: String = (
		"%s · %s" % [TranslationServer.translate(&"BASE_LEVEL_SHORT").format({"n": _next}), _cost]
	)
	var at: Vector2 = Vector2(32, DIG_TOP + DIG_SIZE.y + 14)
	RefText.make(RefText.MONO, 15, RefPaint.DIM).draw(self, at, line, "mm")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _levels.is_empty():
		refresh()
