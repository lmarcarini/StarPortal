class_name MothScreen
extends PanelContainer
## The MOTH scan screen, a mode over the Gate Room (the top bar stays): on the left the SCANS
## (MothScanList), in the middle the camcorder still (MothFrame) generated from the world scene
## as it stands now, on the right the BATTERY with the minutes left, "Recall needs 2 min" and
## RECALL. It shows while a MOTH is out; a recall hides it; a loss shows "SIGNAL LOST" with the
## reason and a Close button until the player closes it. Every order goes through a
## MothScanCommand; nothing here changes state. It refreshes on every MOTH event and tick, when
## it is shown and after each order (so it updates while paused). D-pad picks a scan, A runs
## it, B recalls (or closes SIGNAL LOST).
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH) and section 7 (MOTH scan screen)

## The screen opened or closed.
signal changed

## Phases: HIDDEN, LIVE (a MOTH is out), LOST (the signal was lost; waits for Close).
enum Phase { HIDDEN, LIVE, LOST }

var _simulation: Simulation = null
var _phase: Phase = Phase.HIDDEN
var _lost_world: StringName = &""
var _lost_reason: StringName = &""
var _lost_battery: int = 0

var _scans := MothScanList.new()
var _frame := MothFrame.new()
var _battery_bar := ProgressBar.new()
var _battery_label := Label.new()
var _recall_note := Label.new()
var _result := Label.new()
var _recall_button := Button.new()
var _close_button := Button.new()


func _init() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)
	row.add_child(_scans)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_frame)
	_result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	middle.add_child(_result)
	row.add_child(_build_battery())
	_scans.scan_requested.connect(_on_scan_requested)
	_recall_button.pressed.connect(recall)
	_close_button.pressed.connect(close)


func _enter_tree() -> void:
	for event: Signal in _events():
		event.connect(_on_event)
	EventBus.moth_lost.connect(_on_moth_lost)


func _exit_tree() -> void:
	for event: Signal in _events():
		event.disconnect(_on_event)
	EventBus.moth_lost.disconnect(_on_moth_lost)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()


## Connects the screen to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_phase = Phase.HIDDEN
	refresh()


## Reads the simulation again and shows the MOTH out, the lost signal, or nothing.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var was: Phase = _phase
	if state.probes.moth != null:
		_phase = Phase.LIVE
	elif _phase == Phase.LIVE:
		_phase = Phase.HIDDEN
	visible = _phase != Phase.HIDDEN
	if _phase == Phase.LIVE:
		_show_live(state)
	elif _phase == Phase.LOST:
		_show_lost(state)
	if was != _phase:
		changed.emit()


## Orders the MOTH back (MothScanCommand RECALL); ignored when it cannot be recalled now.
func recall() -> void:
	if _phase == Phase.LOST:
		close()
		return
	_order(MothRules.Scan.RECALL, &"")


## Closes the SIGNAL LOST screen.
func close() -> void:
	if _phase != Phase.LOST:
		return
	_phase = Phase.HIDDEN
	visible = false
	changed.emit()


## Returns the phase.
func get_phase() -> Phase:
	return _phase


## True while the screen shows.
func is_open() -> bool:
	return _phase != Phase.HIDDEN


## Returns the control that should hold focus: a scan, else RECALL or Close.
func get_default_focus() -> Control:
	if _phase == Phase.LOST:
		return _close_button
	var scan: Button = _scans.get_default_focus()
	if scan != null:
		return scan
	return _recall_button


## Returns the SCANS column.
func get_scan_list() -> MothScanList:
	return _scans


## Returns the camcorder still.
func get_frame() -> MothFrame:
	return _frame


## Returns the label under the frame with the text of the last finished scan.
func get_result_label() -> Label:
	return _result


## Returns the RECALL button.
func get_recall_button() -> Button:
	return _recall_button


## Returns the Close button of SIGNAL LOST.
func get_close_button() -> Button:
	return _close_button


## Returns the battery line ("11 min left").
func get_battery_text() -> String:
	return _battery_label.text


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	recall()


func _build_battery() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(200.0, 0.0)
	var title := Label.new()
	title.text = &"MOTH_BATTERY"
	column.add_child(title)
	_battery_bar.max_value = MothRules.BATTERY_MINUTES
	_battery_bar.show_percentage = false
	_battery_bar.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(_battery_bar)
	column.add_child(_battery_label)
	_recall_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recall_note.add_theme_font_size_override(&"font_size", 13)
	column.add_child(_recall_note)
	_recall_button.text = &"MOTH_RECALL"
	column.add_child(_recall_button)
	_close_button.text = &"MOTH_CLOSE"
	column.add_child(_close_button)
	return column


func _show_live(state: GameState) -> void:
	var run: MothRun = state.probes.moth
	_scans.visible = true
	_scans.render(state)
	_battery_bar.value = run.battery_left
	_battery_label.text = MothText.battery_left(run.battery_left)
	_recall_note.text = GateRoomFormat.translate(&"MOTH_RECALL_NEEDS").format(
		{"minutes": MothRules.minutes_of(MothRules.Scan.RECALL)}
	)
	var can_recall: bool = MothScanCommand.create(MothRules.Scan.RECALL).validate(state).is_ok
	_recall_button.visible = true
	_recall_button.disabled = not can_recall
	_close_button.visible = false
	_result.text = MothReportText.finished_text(
		run, WorldFactRules.facts_for_id(state.galaxy, run.world_id)
	)
	var scene: WorldScene = SceneNow.of(state, run.world_id)
	var header: String = (
		"%s   %s" % [MothText.rec(run.battery_left), MothText.world_name(state, run.world_id)]
	)
	var caption: String = MothText.scanning(run, MothScanList.target_name(state, run.target_id))
	var scan: int = run.scan if run.is_scanning() else MothFrameRules.HOVER
	if scene == null:
		_frame.show_lost(header, "", "")
	else:
		_frame.show_frame(MothFrameRules.params_for(scene, scan, run.target_id), header, caption)
	_lost_world = run.world_id
	_lost_battery = run.battery_left


func _show_lost(state: GameState) -> void:
	_scans.visible = false
	_result.text = ""
	_battery_bar.value = 0
	_battery_label.text = MothText.battery_left(_lost_battery)
	_recall_note.text = ""
	_recall_button.visible = false
	_close_button.visible = true
	var header: String = (
		"%s   %s" % [MothText.rec(_lost_battery), MothText.world_name(state, _lost_world)]
	)
	_frame.show_lost(
		header, GateRoomFormat.translate(&"MOTH_SIGNAL_LOST"), MothText.loss_reason(_lost_reason)
	)


func _order(scan: MothRules.Scan, target_id: StringName) -> void:
	if _simulation == null or _phase != Phase.LIVE:
		return
	var result: CommandResult = _simulation.submit(MothScanCommand.create(scan, target_id))
	if result.is_ok:
		refresh()


func _events() -> Array[Signal]:
	return [
		EventBus.tick_advanced,
		EventBus.moth_launched,
		EventBus.moth_scan_started,
		EventBus.moth_scan_finished,
		EventBus.moth_recalled,
		EventBus.world_fact_raised,
		EventBus.world_target_changed,
	]


func _on_event(..._args: Array) -> void:
	refresh()


func _on_scan_requested(scan: int, target_id: StringName) -> void:
	_order(scan as MothRules.Scan, target_id)


func _on_moth_lost(world_id: StringName, reason: StringName) -> void:
	_lost_world = world_id
	_lost_reason = reason
	_phase = Phase.LOST
	refresh()
	changed.emit()
