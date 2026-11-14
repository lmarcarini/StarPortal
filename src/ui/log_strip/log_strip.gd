class_name LogStrip
extends PanelContainer
## The latest Log entries along the bottom of every screen, so the newest news is always at
## hand: one line folded, the last LINES_OPEN lines unfolded. Open shows the full Log in the
## Archive. Reads the running state; redraws when the Log grows (checked each tick), on a
## load and on a language change.
## Bible: docs/content/interface-pass.md section 3 (owner request 2026-11-14)

## The player asked for the full Log.
signal open_log

## Lines shown folded and unfolded.
const LINES_FOLDED: int = 1
const LINES_OPEN: int = 5

## Unfolds to the last few entries, or folds back to one.
var fold_button := Button.new()
## Opens the Archive's Log.
var open_button := Button.new()

var _lines := VBoxContainer.new()
var _open: bool = false
var _shown_count: int = -1


func _init() -> void:
	name = &"LogStrip"
	theme_type_variation = &"StatusStrip"
	var row := HBoxContainer.new()
	add_child(row)
	var title := Label.new()
	title.text = &"LOG_STRIP_TITLE"
	title.theme_type_variation = &"StencilLabel"
	row.add_child(title)
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_lines)
	fold_button.text = &"LOG_STRIP_MORE"
	fold_button.pressed.connect(toggle)
	row.add_child(fold_button)
	open_button.text = &"LOG_STRIP_OPEN"
	open_button.pressed.connect(open_log.emit)
	row.add_child(open_button)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.game_loaded.connect(_on_loaded)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick)
	EventBus.game_loaded.disconnect(_on_loaded)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh(true)


## Keeps [param view]'s bottom edge just above the strip as the strip grows or shrinks.
func keep_above(view: Control) -> void:
	var fit := func() -> void: view.offset_bottom = -maxf(size.y, get_combined_minimum_size().y)
	resized.connect(fit)
	minimum_size_changed.connect(fit)
	fit.call()


## Unfolds or folds the strip.
func toggle() -> void:
	_open = not _open
	fold_button.text = &"LOG_STRIP_LESS" if _open else &"LOG_STRIP_MORE"
	refresh(true)


## True while unfolded.
func is_open() -> bool:
	return _open


## The lines shown now, newest first.
func shown_lines() -> Array[String]:
	var found: Array[String] = []
	for child: Node in _lines.get_children():
		if child is Label and not child.is_queued_for_deletion():
			found.append((child as Label).text)
	return found


## Redraws from the running state when the Log changed, or always when [param force].
func refresh(force: bool = false) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null:
		return
	var entries: Array[LogEntry] = simulation.state.operations_log.entries
	if not force and entries.size() == _shown_count:
		return
	_shown_count = entries.size()
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	var wanted: int = LINES_OPEN if _open else LINES_FOLDED
	for index: int in range(entries.size() - 1, maxi(entries.size() - 1 - wanted, -1), -1):
		_lines.add_child(_line(entries[index], simulation.state))
	if entries.is_empty():
		var empty := Label.new()
		empty.text = &"LOG_STRIP_EMPTY"
		empty.theme_type_variation = &"StencilLabel"
		_lines.add_child(empty)


func _line(entry: LogEntry, state: GameState) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = &"DataLabel"
	var text: String = ArchiveLogRow.line_for(entry, state).replace("\n", " · ")
	label.text = "%s  %s" % [GateRoomFormat.date_time(entry.tick), text]
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _on_tick(_tick: int) -> void:
	refresh()


func _on_loaded(_slot: StringName) -> void:
	refresh(true)
