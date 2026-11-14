extends Control
## Main scene. Starts a new paused game, wires the time bar, quick save and quick load, the
## autosave on each new day, the Committee's messages, the game views under the top bar and,
## in debug builds only, the debug overlay and a button that submits a SetFlagCommand. It also
## hosts the rescue alert over the current tab (not modal) with its entry on the top bar's alert
## stack, and shows each team check-in as a message that never pauses. Holds no game rules: it
## reads state and sends commands.
## Bible: game-design.md#time-real-time-with-pause, game-design.md#core-loop,
## technical-architecture.md#architecture-overview,
## docs/content/m3-beyond-the-ring.md sections 4 and 7

## Smallest window size the game supports, in pixels.
const MIN_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## Save slot used by quick save and quick load.
const QUICK_SLOT: StringName = &"quick"
## Flag the debug button sets, to a count of its presses.
const DEBUG_FLAG_KEY: StringName = &"debug_counter"
## Seconds a toast stays on screen.
const TOAST_SECONDS: float = 2.0
## Seconds a Committee message (commendation, warning) stays on screen.
const COMMITTEE_MESSAGE_SECONDS: float = 6.0

const _DEBUG_OVERLAY_SCENE: String = "res://src/ui/debug/debug_overlay.tscn"
const _ACTION_QUICK_SAVE: StringName = &"quick_save"
const _ACTION_QUICK_LOAD: StringName = &"quick_load"

## Seed of the new game started in _ready(); negative takes one from the system clock.
## Tests set it before the shell enters the tree.
var new_game_seed: int = -1
## The debug overlay; null in release builds.
var debug_overlay: DebugOverlay = null

## Grain and vignette over the whole screen (display/screen_grain setting).
var screen_grain := ScreenGrain.new()

var _simulation: Simulation = null
var _debug_flag_count: int = 0
var _rescue_alert := RescueAlert.new()
var _alert_stack := AlertStack.new()
var _conversation := ConversationPanel.new()

## The bar on every screen (docs/content/interface-pass.md section 3).
@onready var top_bar: TopBar = %TopBar
## The time bar at the top of the screen.
@onready var time_bar: TimeBar = top_bar.time_bar
## The game views and their tabs, under the top bar.
@onready var view_switcher: ViewSwitcher = %ViewSwitcher
## The money display in the top bar.
@onready var money_label: MoneyLabel = top_bar.money_label
## The Committee Confidence readout beside the funds.
@onready var confidence_readout: ConfidenceReadout = top_bar.confidence_readout
@onready var _quick_save_button: Button = top_bar.quick_save_button
@onready var _quick_load_button: Button = top_bar.quick_load_button
@onready var _debug_flag_button: Button = top_bar.debug_flag_button
@onready var _toast: Label = %Toast
@onready var _toast_timer: Timer = %ToastTimer


func _ready() -> void:
	_apply_min_window_size()
	_apply_theme()
	add_child(screen_grain)
	_quick_save_button.pressed.connect(quick_save)
	_quick_load_button.pressed.connect(quick_load)
	top_bar.open_view.connect(open_view)
	top_bar.alert_chosen.connect(_on_alert_chosen)
	top_bar.resized.connect(_fit_below_top_bar)
	_toast_timer.timeout.connect(_toast.hide)
	_add_alerts()
	add_child(_conversation)
	_setup_debug_tools()
	_start(GameState.new_game(_choose_seed(), Registry.balance()), true)
	SimClock.pause()
	_bind_views(_simulation)
	var buttons: Array[Button] = get_focus_order()
	_link_focus(buttons, view_switcher.get_tab_bar())
	view_switcher.set_focus_above(buttons[0])
	buttons[0].grab_focus()


func _enter_tree() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.committee_commendation.connect(_on_commendation)
	EventBus.committee_warning.connect(_on_committee_warning)
	EventBus.team_checked_in.connect(_on_team_checked_in)
	EventBus.prologue_completed.connect(_on_prologue_completed)
	EventBus.request_changed.connect(_on_request_changed)
	EventBus.artefact_hazard.connect(_on_artefact_hazard)
	Settings.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	EventBus.day_started.disconnect(_on_day_started)
	EventBus.committee_commendation.disconnect(_on_commendation)
	EventBus.committee_warning.disconnect(_on_committee_warning)
	EventBus.team_checked_in.disconnect(_on_team_checked_in)
	EventBus.prologue_completed.disconnect(_on_prologue_completed)
	EventBus.request_changed.disconnect(_on_request_changed)
	EventBus.artefact_hazard.disconnect(_on_artefact_hazard)
	Settings.setting_changed.disconnect(_on_setting_changed)
	if _simulation != null and SimClock.simulation == _simulation:
		SimClock.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(_ACTION_QUICK_SAVE):
		quick_save()
	elif event.is_action_pressed(_ACTION_QUICK_LOAD):
		quick_load()
	else:
		return
	get_viewport().set_input_as_handled()


## Saves the running game to slot [constant QUICK_SLOT] and shows a toast.
func quick_save() -> void:
	var result: Result = SaveService.save_game(_simulation.state, QUICK_SLOT)
	if not result.is_ok:
		push_warning("Shell: quick save failed: %s %s" % [result.error_code, result.detail])
		_show_toast(&"UI_SAVE_FAILED")
		return
	_show_toast(&"UI_SAVED")


## Loads slot [constant QUICK_SLOT], restarts SimClock with it and shows a toast. On failure
## the running game carries on.
func quick_load() -> void:
	var result: Result = SaveService.load_game(QUICK_SLOT, GameDefs.from_registry(Registry))
	if not result.is_ok:
		if result.error_code == &"missing_file":
			_show_toast(&"UI_QUICK_SAVE_MISSING")
			return
		if result.error_code == &"old_format_version":
			_show_toast(&"UI_LOAD_OLD_SAVE")
			return
		push_warning("Shell: quick load failed: %s %s" % [result.error_code, result.detail])
		_show_toast(&"UI_LOAD_FAILED")
		return
	var state: GameState = result.value
	if not _start(state):
		_show_toast(&"UI_LOAD_FAILED")
		return
	_bind_views(_simulation)
	_show_toast(&"UI_LOADED")


## Opens the Command tab (the funds and Conf. readouts in the top bar;
## docs/content/m27-daily-rhythm.md section 4).
func open_command() -> void:
	view_switcher.show_view(ViewSwitcher.COMMAND)


## Shows [param view_id], on the Base's [param sub_tab] when one is given (the top bar).
func open_view(view_id: StringName, sub_tab: StringName = &"") -> void:
	view_switcher.show_view(view_id)
	var base: BaseView = view_switcher.get_view(view_id) as BaseView
	if base != null and sub_tab != &"" and view_switcher.current_view_id() == view_id:
		base.get_sub_tabs().show_tab(sub_tab)


## Selects the target of the alert [param entry] once its screen is open: a research project;
## the rescue alert opens the rescue window.
func _on_alert_chosen(entry: AlertEntry) -> void:
	if entry.kind == &"rescue":
		_rescue_alert.open()
		return
	var research: ResearchView = view_switcher.get_view(entry.view_id) as ResearchView
	if research != null and entry.target != &"" and research.is_available():
		research.get_board().jump_to(entry.target)
		research.get_board().project_chosen.emit(entry.target)


## Returns the rescue alert.
func get_rescue_alert() -> RescueAlert:
	return _rescue_alert


## Returns the conversation panel.
func get_conversation_panel() -> ConversationPanel:
	return _conversation


## Returns the top bar's alert stack.
func get_alert_stack() -> AlertStack:
	return _alert_stack


## Returns every button in focus order: the time bar's, the alert stack's (while shown), the
## funds, Confidence, power, gate and alerts, then save, load and (debug only) the flag
## button. Neighbours wrap around, so a gamepad reaches them all; down from any of them is
## the view tabs.
func get_focus_order() -> Array[Button]:
	var extra: Array[Button] = []
	if _alert_stack.get_rescue_button().visible:
		extra.append(_alert_stack.get_rescue_button())
	return top_bar.get_focus_buttons(extra)


## Returns the text of the toast on screen, or "" when none is shown.
func get_toast_text() -> String:
	return _toast.text if _toast.visible else ""


func _apply_min_window_size() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.min_size = MIN_WINDOW_SIZE


func _choose_seed() -> int:
	if new_game_seed >= 0:
		return new_game_seed
	return int(Time.get_unix_time_from_system() * 1000.0)


## Builds the Simulation for [param state] through GameSetup, from the Registry's content,
## and binds it to SimClock; a [param is_new_game] goes through GameSetup.build_new(). Returns
## false, keeping the running game, when the state cannot be set up (e.g. a save from another
## galaxy generator version).
func _start(state: GameState, is_new_game: bool = false) -> bool:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = (
		GameSetup.build_new(state, defs) if is_new_game else GameSetup.build(state, defs)
	)
	if not built.is_ok:
		push_warning("Shell: cannot set up the game: %s %s" % [built.error_code, built.detail])
		return false
	_simulation = built.value
	SimClock.start(_simulation)
	time_bar.refresh()
	return true


## Adds the debug overlay and keeps the flag button in debug builds; removes the button in
## release builds, where neither exists.
func _setup_debug_tools() -> void:
	if not OS.is_debug_build():
		_debug_flag_button.queue_free()
		_debug_flag_button = null
		return
	_debug_flag_button.pressed.connect(_on_debug_flag_pressed)
	var scene: PackedScene = load(_DEBUG_OVERLAY_SCENE)
	debug_overlay = scene.instantiate() as DebugOverlay
	add_child(debug_overlay)


static func _link_focus(buttons: Array[Button], below: Control) -> void:
	var count: int = buttons.size()
	for index: int in count:
		var button: Button = buttons[index]
		var previous: NodePath = button.get_path_to(buttons[(index - 1 + count) % count])
		var next: NodePath = button.get_path_to(buttons[(index + 1) % count])
		button.focus_neighbor_left = previous
		button.focus_previous = previous
		button.focus_neighbor_right = next
		button.focus_next = next
		button.focus_neighbor_top = NodePath(".")
		button.focus_neighbor_bottom = button.get_path_to(below)


## Passes [param simulation] to the game views. Called after each [method _start]: at start
## and after a quick load.
func _bind_views(simulation: Simulation) -> void:
	view_switcher.setup(simulation)
	_rescue_alert.setup(simulation)
	_conversation.setup(simulation)
	top_bar.bind(simulation)


## Puts the alert stack in the top bar after the time bar, and the rescue alert over the top
## of the current tab, below the tab bar.
func _add_alerts() -> void:
	top_bar.add_after_clock(_alert_stack)
	add_child(_rescue_alert)
	_rescue_alert.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_rescue_alert.offset_left = 16.0
	_rescue_alert.offset_right = -16.0
	_rescue_alert.offset_top = view_switcher.offset_top + 48.0
	_fit_below_top_bar()
	_rescue_alert.gate_room_requested.connect(view_switcher.show_view.bind(ViewSwitcher.GATE_ROOM))
	_alert_stack.setup(_rescue_alert)
	top_bar.alert_list.set_rescue(_rescue_alert)
	_rescue_alert.changed.connect(_relink_top_bar)


## Links the top bar's buttons again once the alert stack's entry shows or hides.
func _relink_top_bar() -> void:
	if not is_node_ready():
		return
	_link_focus(get_focus_order(), view_switcher.get_tab_bar())


func _on_team_checked_in(world_id: StringName, light: int, serious: int, _day: String) -> void:
	if _simulation == null:
		return
	var world: String = AddressBookText.name_of_world(world_id, _simulation.state)
	var args: Dictionary = {"reason": "checked_in", "light": light, "serious": serious}
	show_message(ExpeditionLogText.line(args, world), COMMITTEE_MESSAGE_SECONDS)


## The Prologue ends at the first team's return home (docs/content/m3-beyond-the-ring.md
## section 1): a message that never pauses.
func _on_prologue_completed(_world_id: StringName) -> void:
	show_message(tr(&"LOG_LINE_PROLOGUE_COMPLETE"), COMMITTEE_MESSAGE_SECONDS)


func _show_toast(key: StringName) -> void:
	show_message(tr(key), TOAST_SECONDS)


## Shows [param line] in the toast for [param seconds]; the game never pauses for it. Used for
## save results and the Committee's commendation and warnings
## (docs/content/m27-daily-rhythm.md section 2).
func show_message(line: String, seconds: float) -> void:
	_toast.text = line
	_toast.show()
	_toast_timer.start(seconds)


func _on_commendation(amount_k: int) -> void:
	show_message(CommitteeText.commendation_line(amount_k), COMMITTEE_MESSAGE_SECONDS)


func _on_committee_warning(reason: StringName) -> void:
	var days: int = 0 if _simulation == null else _simulation.state.committee.days_in_red
	show_message(CommitteeText.warning_line(reason, days), COMMITTEE_MESSAGE_SECONDS)


func _on_day_started(_day_index: int) -> void:
	if _simulation == null or SimClock.simulation != _simulation:
		return
	var result: Result = SaveService.autosave(_simulation.state)
	if result.is_ok:
		return
	push_warning("Shell: autosave failed: %s %s" % [result.error_code, result.detail])
	_show_toast(&"UI_AUTOSAVE_FAILED")


func _on_debug_flag_pressed() -> void:
	_debug_flag_count += 1
	_simulation.submit(SetFlagCommand.create(DEBUG_FLAG_KEY, _debug_flag_count))


## A non-pausing message when a request is fulfilled or fails.
func _on_request_changed(uid: int, to: int) -> void:
	var fulfilled: int = RequestRecord.RequestState.FULFILLED
	if _simulation == null or (to != fulfilled and to != RequestRecord.RequestState.FAILED):
		return
	var record: RequestRecord = RequestRules.find(_simulation.state, uid)
	if record != null:
		show_message(RequestLog.line({"request_id": String(record.request), "state": to}), 4.0)


## A non-pausing message when an artefact's hazard strikes.
func _on_artefact_hazard(artefact_id: StringName) -> void:
	show_message(ArtefactText.hazard_line(artefact_id), 4.0)


## Applies the interface theme at the current UI scale and paints the ground colour.
func _apply_theme() -> void:
	theme = UiThemeBuilder.build(Settings.get_float(&"display", &"ui_scale"))
	RenderingServer.set_default_clear_color(UiPalette.GROUND)


func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"display" and key == &"ui_scale":
		_apply_theme()


## Keeps the views and the rescue alert just under the top bar, which grows to two rows in a
## narrow window.
func _fit_below_top_bar() -> void:
	view_switcher.offset_top = top_bar.size.y
	_rescue_alert.offset_top = top_bar.size.y + 48.0
