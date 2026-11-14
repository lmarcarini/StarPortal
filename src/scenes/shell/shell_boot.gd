class_name ShellBoot
extends RefCounted
## Small start-up helpers for the shell: the seed of a new game and the window's minimum size.
## Bible: docs/bible/technical-architecture.md#architecture-overview

## The main menu, where return_to_menu goes.
const MENU_SCENE: String = "res://src/scenes/main_menu/main_menu.tscn"


## [param new_game_seed] when set (tests), else one from the clock.
static func choose_seed(new_game_seed: int) -> int:
	if new_game_seed >= 0:
		return new_game_seed
	return int(Time.get_unix_time_from_system() * 1000.0)


## Sets [param window]'s minimum size to [param size] (nothing without a window).
static func apply_min_window_size(window: Window, size: Vector2i) -> void:
	if window != null:
		window.min_size = size


## Links [param buttons] into a ring (left/right wrap) with [param below] under each.
static func link_focus(buttons: Array[Button], below: Control) -> void:
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


## Adds [param menu] over [param shell] and joins it to the shell's save, load and menu.
static func add_pause_menu(shell: Node, menu: PauseMenu) -> void:
	shell.add_child(menu)
	menu.save_requested.connect(Callable(shell, &"save_slot"))
	menu.load_requested.connect(Callable(shell, &"load_slot"))
	menu.menu_requested.connect(Callable(shell, &"return_to_menu"))


## Shows the Archive's Log in [param view_switcher] (the log strip's Open).
static func open_log(view_switcher: ViewSwitcher) -> void:
	view_switcher.show_view(ViewSwitcher.ARCHIVE)
	var archive: ArchiveView = view_switcher.get_view(ViewSwitcher.ARCHIVE) as ArchiveView
	if archive != null:
		archive.show_section(true)


## Applies the settings the simulation reads to [param simulation]: Failure states (M4c-14).
static func apply_settings(simulation: Simulation) -> void:
	var on: bool = Settings.get_bool(&"gameplay", &"failure_states")
	simulation.state.outcome.enabled = on


## Adds the after-action report (M4c-13) and the game over screen (M4c-15) over
## [param shell] and joins it to the shell's load and
## menu; returns it.
static func add_game_over(shell: Node) -> GameOverScreen:
	var screen := GameOverScreen.new()
	shell.add_child(screen)
	screen.load_requested.connect(Callable(shell, &"load_slot"))
	screen.menu_requested.connect(Callable(shell, &"return_to_menu"))
	shell.add_child(AfterActionReport.new())
	return screen
