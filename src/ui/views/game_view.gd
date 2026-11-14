@abstract class_name GameView
extends Control
## Base of every game view the [ViewSwitcher] hosts (Gate Room, Analysis, and later Base,
## Expeditions, Research and Command). A view reads the running simulation and submits
## commands to it; it keeps its own UI state while hidden, because the switcher only hides it.
## Inheritance stops here: a view extends this class and nothing extends a view.
## Bible: game-design.md#core-loop, technical-architecture.md#signals-and-scenes,
## technical-architecture.md#input-accessibility-and-localisation

## Emitted when [method is_available] may have changed; the switcher then shows or hides
## the view's tab.
signal availability_changed
## Emitted when [method get_tab_title] may have changed; the switcher then rereads it.
signal title_changed

## Called by the switcher before the view is shown, and again after a load with the new
## [param simulation]. The view drops anything it read from the previous one.
@abstract func setup(simulation: Simulation) -> void

## Returns the control that takes focus when the view opens (gamepad). It must be focusable.
@abstract func get_default_focus() -> Control

## Returns the translation key of the view's tab title.
@abstract func get_title_key() -> StringName


## Returns the translated tab title; a view may add to it (a count, a dot).
func get_tab_title() -> String:
	return tr(get_title_key())


## True while something inside the view needs the player; the switcher shows a dot on its
## tab (docs/content/interface-pass.md section 4). Emit [signal title_changed] when it may
## have changed.
func needs_attention() -> bool:
	return false


## False while the view's tab is hidden (the Research tab before a lab finishes). The
## switcher hides the tab, skips it with view_next and view_previous, and ignores its action.
func is_available() -> bool:
	return true
