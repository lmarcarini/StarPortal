extends Control
## Main scene. Starts a new paused game, wires the time bar, quick save and quick load, the
## autosave on each new day, the game views under the top bar and, in debug builds only, the
## debug overlay and a button that submits a SetFlagCommand. Holds no game rules: it reads
## state and sends commands.
## Bible: game-design.md#time-real-time-with-pause, game-design.md#core-loop,
## technical-architecture.md#architecture-overview

## Smallest window size the game supports, in pixels.
const MIN_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## Save slot used by quick save and quick load.
const QUICK_SLOT: StringName = &"quick"
## Flag the debug button sets, to a count of its presses.
const DEBUG_FLAG_KEY: StringName = &"debug_counter"
## Seconds a toast stays on screen.
const TOAST_SECONDS: float = 2.0

const _DEBUG_OVERLAY_SCENE: String = "res://src/ui/debug/debug_overlay.tscn"
const _ACTION_QUICK_SAVE: StringName = &"quick_save"
const _ACTION_QUICK_LOAD: StringName = &"quick_load"

## Seed of the new game started in _ready(); negative takes one from the system clock.
## Tests set it before the shell enters the tree.
var new_game_seed: int = -1
## The debug overlay; null in release builds.
var debug_overlay: DebugOverlay = null

var _simulation: Simulation = null
var _debug_flag_count: int = 0

## The time bar at the top of the screen.
@onready var time_bar: TimeBar = %TimeBar
## The game views and their tabs, under the top bar.
@onready var view_switcher: ViewSwitcher = %ViewSwitcher
@onready var _quick_save_button: Button = %QuickSaveButton
@onready var _quick_load_button: Button = %QuickLoadButton
@onready var _debug_flag_button: Button = %DebugFlagButton
@onready var _toast: Label = %Toast
@onready var _toast_timer: Timer = %ToastTimer


func _ready() -> void:
	_apply_min_window_size()
	_quick_save_button.pressed.connect(quick_save)
	_quick_load_button.pressed.connect(quick_load)
	_toast_timer.timeout.connect(_toast.hide)
	_setup_debug_tools()
	_start(GameState.new_game(_choose_seed(), Registry.balance()))
	SimClock.pause()
	_bind_views(_simulation)
	var buttons: Array[Button] = get_focus_order()
	_link_focus(buttons, view_switcher.get_tab_bar())
	view_switcher.set_focus_above(buttons[0])
	buttons[0].grab_focus()


func _enter_tree() -> void:
	EventBus.day_started.connect(_on_day_started)


func _exit_tree() -> void:
	EventBus.day_started.disconnect(_on_day_started)
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
	var result: Result = SaveService.load_game(QUICK_SLOT)
	if not result.is_ok:
		if result.error_code == &"missing_file":
			_show_toast(&"UI_QUICK_SAVE_MISSING")
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


## Returns every button in focus order: the time bar's, then save, load and (debug only)
## the flag button. Neighbours wrap around, so a gamepad reaches them all; down from any of
## them is the view tabs.
func get_focus_order() -> Array[Button]:
	var buttons: Array[Button] = time_bar.get_buttons()
	buttons.append_array([_quick_save_button, _quick_load_button])
	if _debug_flag_button != null:
		buttons.append(_debug_flag_button)
	return buttons


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
## and binds it to SimClock. Returns false, keeping the running game, when the state cannot
## be set up (e.g. a save from another galaxy generator version).
func _start(state: GameState) -> bool:
	var built: Result = GameSetup.build(state, GameDefs.from_registry(Registry))
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


func _show_toast(key: StringName) -> void:
	_toast.text = tr(key)
	_toast.show()
	_toast_timer.start(TOAST_SECONDS)


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
