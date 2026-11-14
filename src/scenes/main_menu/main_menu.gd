class_name MainMenu
extends Control
## The main menu the game opens on: Continue (the newest save, autosave included; hidden
## when there is none), New game, Load, Scenarios (hidden while there are none) and Quit.
## Nothing ticks behind it. A load that fails shows its reason here and the menu stays.
## Keyboard and gamepad move through the buttons; uses the interface theme.
## Bible: docs/bible/technical-architecture.md#architecture-overview,
## docs/content/interface-pass.md section 2

## The shell scene a game runs in.
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

## False in tests: choosing a game sets GameStart but does not change scene.
var changes_scene: bool = true
## The menu's buttons.
var continue_button := Button.new()
var new_button := Button.new()
var load_button := Button.new()
var scenarios_button := Button.new()
var quit_button := Button.new()
## The reason a load failed, under the buttons.
var message := Label.new()

var _column := VBoxContainer.new()


func _init() -> void:
	name = &"MainMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelBezel"
	centre.add_child(panel)
	_column.add_theme_constant_override(&"separation", 10)
	_column.custom_minimum_size.x = 360
	panel.add_child(_column)
	var title := Label.new()
	title.text = &"MENU_TITLE"
	title.theme_type_variation = &"HeaderStrip"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var labels: Dictionary[Button, StringName] = {
		continue_button: &"MENU_CONTINUE",
		new_button: &"MENU_NEW_GAME",
		load_button: &"MENU_LOAD",
		scenarios_button: &"MENU_SCENARIOS",
		quit_button: &"MENU_QUIT",
	}
	for button: Button in labels:
		button.text = labels[button]
		button.theme_type_variation = &"KeyButton"
		button.custom_minimum_size.y = 44
		_column.add_child(button)
	message.theme_type_variation = &"StencilLabel"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.visible = false
	_column.add_child(message)
	continue_button.pressed.connect(continue_game)
	new_button.pressed.connect(new_game)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


func _ready() -> void:
	theme = UiThemeBuilder.build(Settings.get_float(&"display", &"ui_scale"))
	RenderingServer.set_default_clear_color(UiPalette.GROUND)
	SimClock.stop()
	refresh()
	first_button().grab_focus.call_deferred()


## Shows Continue only with a save to continue and Scenarios only with scenarios; Load waits
## for the load list.
func refresh() -> void:
	continue_button.visible = not SaveService.list_slots().is_empty()
	load_button.visible = false
	scenarios_button.visible = false


## The first visible button (Continue, or New game without saves).
func first_button() -> Button:
	return continue_button if continue_button.visible else new_button


## Starts a fresh game (paused, as always).
func new_game() -> void:
	GameStart.start_new()
	_open_shell()


## Loads the newest save; on failure shows why and stays on the menu.
func continue_game() -> void:
	var slots: Array[Dictionary] = SaveService.list_slots()
	if slots.is_empty():
		show_message(&"MENU_NO_SAVE")
		return
	var slot: StringName = slots[0]["slot"]
	open_slot(slot)


## Loads [param slot] and opens it; on failure shows why and stays on the menu. Returns true
## when the game opened.
func open_slot(slot: StringName) -> bool:
	var result: Result = SaveService.load_game(slot, GameDefs.from_registry(Registry))
	if not result.is_ok:
		show_message(load_error_key(result.error_code))
		return false
	var state: GameState = result.value
	GameStart.start_slot(slot, state)
	_open_shell()
	return true


## The message key for a failed load's [param error_code].
static func load_error_key(error_code: StringName) -> StringName:
	match error_code:
		&"missing_file":
			return &"UI_QUICK_SAVE_MISSING"
		&"old_format_version":
			return &"UI_LOAD_OLD_SAVE"
	return &"UI_LOAD_FAILED"


## Shows [param key]'s text under the buttons.
func show_message(key: StringName) -> void:
	message.text = tr(key)
	message.visible = true


func _open_shell() -> void:
	if changes_scene and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(SHELL_SCENE)
