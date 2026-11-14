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
