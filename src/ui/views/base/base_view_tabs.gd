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

## The Staff sub-tab strip, shown in place of the palette.
var staff_tab := StaffSubTab.new()
## The Security strip (M4c-12), shown in place of the palette.
var security_tab := SecuritySubTab.new()

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
	_attach_staff()
	_palette.get_parent().add_child(security_tab)
	security_tab.squad_picked.connect(_on_squad_picked)
	show_sub_tab()


## Puts the Staff strip under the plan, in the plan's column (so it never overlaps the plan,
## the sub-tabs or the message line), and joins it to the plan's staff layer.
func _attach_staff() -> void:
	_palette.get_parent().add_child(staff_tab)
	staff_tab.person_chosen.connect(_on_staff_person)
	staff_tab.assign_pressed.connect(_on_assign_pressed)
	_plan.placement_message.connect(_on_placement_message)
	_plan.drag_moved.connect(_on_drag_moved)
	_plan.staff_layer.token_selected.connect(_refresh_staff.unbind(1))
	staff_tab.staff_changed.connect(_refresh_staff)


func _refresh_staff() -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation != null and staff_tab.visible:
		staff_tab.show_state(simulation.state, _plan.staff_layer.selected())


func _on_staff_person(person_id: StringName) -> void:
	_plan.staff_layer.focus_person(person_id)


func _on_assign_pressed() -> void:
	_plan.start_placing(_plan.staff_layer.selected())


func _on_placement_message(text: String) -> void:
	staff_tab.show_hint(text)
	if not text.is_empty():
		_palette.show_message(text)


## Holding a token over a level tab shows that level, so a drop can go to another level.
func _on_drag_moved(global_point: Vector2) -> void:
	var number: int = 0
	for child: Node in _levels.get_children():
		var button := child as Button
		if button == null or button == _levels.next_tab:
			continue
		number += 1
		if button.is_visible_in_tree() and button.get_global_rect().has_point(global_point):
			if number != _plan.level:
				_plan.show_level(number)
			return


## Shows the sub-tab the energy layer stands for, and moves focus off anything it hid.
func show_sub_tab() -> void:
	var energy: bool = _power.is_layer_on()
	var staff: bool = not energy and _sub_tabs.shown() == BaseSubTabs.STAFF
	var security: bool = not energy and _sub_tabs.shown() == BaseSubTabs.SECURITY
	_sub_tabs.set_block_signals(true)
	var tab: StringName = BaseSubTabs.ENERGY if energy else BaseSubTabs.BUILD
	if staff or security:
		tab = _sub_tabs.shown()
	_sub_tabs.show_tab(tab)
	_sub_tabs.set_block_signals(false)
	_palette.visible = not energy and not staff and not security
	_power.strip.visible = energy
	_palette.message_line.visible = energy
	staff_tab.visible = staff
	_show_security(security)
	_plan.staff_layer.tint = staff
	_refresh_staff()
	_keep_focus()


func _show_security(on: bool) -> void:
	security_tab.visible = on
	var simulation: Simulation = SimClock.simulation
	if simulation != null:
		_sub_tabs.show_security_for(simulation.state)
		if on:
			security_tab.show_state(simulation.state)
	_on_squad_picked(security_tab.selected if on else &"")


# A picked squad: its room shows in the detail column (its camera), the plan previews its
# path to the cursor, and Enter or a click on the plan orders it there.
func _on_squad_picked(squad_id: StringName) -> void:
	_plan.security_layer.preview_squad = squad_id
	if squad_id.is_empty():
		_plan.order_target = Callable()
		return
	_plan.order_target = _order_move
	var simulation: Simulation = SimClock.simulation
	var squad: SquadState = simulation.state.security.squad_of(squad_id)
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(
		simulation.state.base, simulation.state.room_defs
	)
	var room: RoomState = cells.get(squad.pos)
	if room != null:
		_plan.select(room.id)
	_plan.grab_focus()


func _order_move(cell: Vector3i) -> void:
	security_tab.order(SquadState.Order.MOVE, cell)


## Moves the palette's message line under the plan, where both sub-tabs show it: the power
## news of BaseMessages matters most on Energy.
func _move_message_line() -> void:
	var line: HBoxContainer = _palette.message_line
	line.get_parent().remove_child(line)
	_palette.get_parent().add_child(line)


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
	else:
		show_sub_tab()


## DIG under the level keys: digs the next level at once (the palette's Dig command); when
## refused, the message line says why.
func _on_dig_chosen() -> void:
	var dig: DigButton = _palette.get_dig_button()
	if dig.press_now():
		return
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
