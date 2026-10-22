@abstract class_name GameView
extends Control
## Base of every game view the [ViewSwitcher] hosts (Gate Room, Analysis, and later Base,
## Expeditions, Research and Command). A view reads the running simulation and submits
## commands to it; it keeps its own UI state while hidden, because the switcher only hides it.
## Inheritance stops here: a view extends this class and nothing extends a view.
## Bible: game-design.md#core-loop, technical-architecture.md#signals-and-scenes,
## technical-architecture.md#input-accessibility-and-localisation

## Called by the switcher before the view is shown, and again after a load with the new
## [param simulation]. The view drops anything it read from the previous one.
@abstract func setup(simulation: Simulation) -> void

## Returns the control that takes focus when the view opens (gamepad). It must be focusable.
@abstract func get_default_focus() -> Control

## Returns the translation key of the view's tab title.
@abstract func get_title_key() -> StringName
