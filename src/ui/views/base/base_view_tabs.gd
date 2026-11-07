class_name BaseViewTabs
extends Node
## The Base tab's sub-tab wiring (docs/content/m2-base.md section 6), kept apart from
## [BaseView]: the [BaseSubTabs] bar stands for the energy layer of [BaseViewPower] (Energy is
## the layer on, Build the layer off), so P or View, a click on the bar and the gamepad
## shoulders all move the same state. Build shows the palette and the ghost level tab; Energy
## hides them; the message line sits under the plan on both. Focus never goes to a hidden
## control: leaving Build moves it to the selected room's switch or the plan, and Esc or (B)
## on the plan in Energy keeps it there. The ghost level tab goes back to Build and onto the
## palette's Dig entry.
## Bible: docs/content/m2-base.md section 6; docs/content/m25-lean-start.md section 3

var _sub_tabs: BaseSubTabs = null
var _levels: LevelTabs = null
var _plan: BasePlan = null
var _palette: BuildPalette = null
var _power: BaseViewPower = null
var _build: BaseBuild = null


## Joins the bar [param sub_tabs] and the [param levels] column to the view's [param power]
## and [param build] (whose plan and palette it reads).
func attach(
	sub_tabs: BaseSubTabs, levels: LevelTabs, power: BaseViewPower, build: BaseBuild
) -> void:
	_sub_tabs = sub_tabs
	_levels = levels
	_power = power
	_build = build
	_plan = build.get_plan()
	_palette = build.get_palette()
	_sub_tabs.sub_tab_changed.connect(_on_sub_tab_changed)
	_levels.dig_chosen.connect(_on_dig_chosen)
	_palette.room_picked.connect(_close_energy_layer.unbind(1))
	_power.layer.visibility_changed.connect(_on_energy_layer_toggled)
	_move_message_line()
	show_sub_tab()


## Shows the sub-tab the energy layer stands for, and moves focus off anything it hid.
func show_sub_tab() -> void:
	var energy: bool = _power.is_layer_on()
	_sub_tabs.set_block_signals(true)
	_sub_tabs.show_tab(BaseSubTabs.ENERGY if energy else BaseSubTabs.BUILD)
	_sub_tabs.set_block_signals(false)
	_palette.visible = not energy
	_levels.next_tab.visible = not energy and _levels.has_next()
	_keep_focus()


## Moves the palette's message line under the plan, where both sub-tabs show it: the power
## news of BaseMessages matters most on Energy.
func _move_message_line() -> void:
	var line: HBoxContainer = _palette.message_line
	line.get_parent().remove_child(line)
	_plan.get_parent().add_child(line)


## Handles the shoulders (sub-tabs) and Esc or (B) on the plan in Energy; true when it did.
func handle_input(event: InputEvent) -> bool:
	var shoulder: int = BaseSubTabs.shoulder_step(event)
	if shoulder != 0 and _sub_tabs.step(shoulder):
		_keep_focus()
		return true
	return _power.is_layer_on() and _plan.has_focus() and event.is_action_pressed(&"ui_cancel")


## Placing a room closes the energy layer, so (A) on the plan builds and toggles nothing.
func _close_energy_layer() -> void:
	if _power.is_layer_on():
		_power.toggle_layer()


## Opening the energy layer puts the ghost away, so (A) toggles rooms and builds nothing.
func _on_energy_layer_toggled() -> void:
	if _power.is_layer_on() and _build.get_ghost().is_placing():
		_build.get_ghost().stop(true)
	show_sub_tab()


## Picking a sub-tab turns the energy layer on for Energy and off for Build.
func _on_sub_tab_changed(tab: StringName) -> void:
	if (tab == BaseSubTabs.ENERGY) != _power.is_layer_on():
		_power.toggle_layer()


## The ghost level tab: back to Build and onto the palette's Dig entry, which holds to dig.
func _on_dig_chosen() -> void:
	_sub_tabs.show_tab(BaseSubTabs.BUILD)
	var dig: DigButton = _palette.get_dig_button()
	if dig.visible:
		dig.grab_focus()
	_palette.show_message(dig.text if dig.get_reason().is_empty() else dig.get_reason())


## With the tab shown and nothing focused (a hidden control lost it), focuses the selected
## room's switch in Energy, else the plan.
func _keep_focus() -> void:
	if not _plan.is_visible_in_tree() or _plan.get_viewport().gui_get_focus_owner() != null:
		return
	var switch: Button = _power.room_switch.get_button()
	if _power.is_layer_on() and switch.is_visible_in_tree() and not switch.disabled:
		switch.grab_focus()
	else:
		_plan.grab_focus()
