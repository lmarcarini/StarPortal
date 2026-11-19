class_name BaseView
extends GameView
## The Base tab (F3): the [BaseSubTabs] bar (Build and Energy), the level column, the plan of
## the shown level and the selected-room panel (docs/content/m2-base.md section 6). Build shows
## the build palette under them (wired in its own section below, through [BaseBuild]) and the
## ghost tab of the next level to dig; Energy is the energy layer of [BaseViewPower], with its
## switches and charge control; its power strip shows on both. P or View jumps between them,
## the gamepad shoulders step through them and then the main tabs, and base_level_up and
## base_level_down (PageUp and PageDown, (Y) and (X)) change level. The panel ends with the
## selected room's [StaffSlots].
## Bible: docs/content/m2-base.md section 6, game-design.md#base-building-and-power

## Ticks of work per step of the progress bars: a tick redraws the tab only when a site's,
## demolition's or dig's work left crosses a step.
const PROGRESS_STEP_TICKS: int = 5

## The selected room's camera inset in the detail column.
var room_camera := RoomCamera.new()

var _simulation: Simulation = null
var _defs: Dictionary = {}
## What the plan last drew from; a tick redraws only when it changes.
var _signature: int = 0
## Building (card #140), wired in its own section at the end.
var _build: BaseBuild = null
## The power strip, switches and energy layer (card #141).
var _power: BaseViewPower = BaseViewPower.new()
## The message line's building and power news (card M2.5-07).
var _messages: BaseMessages = BaseMessages.new()
## The selected room's staff slots (card M2.6-09).
var _slots: StaffSlots = StaffSlots.new()
var _room_artefacts := ArtefactPanel.new()
## The Build and Energy sub-tabs (card #206).
var _tabs: BaseViewTabs = BaseViewTabs.new()
## The console's mode keys (M6-02).
var _mode_keys: BaseModeKeys = BaseModeKeys.new()

@onready var _sub_tabs: BaseSubTabs = %SubTabs
@onready var _levels: LevelTabs = %LevelTabs
@onready var _heading: Label = %LevelHeading
@onready var _plan: BasePlan = %Plan
@onready var _panel: RoomPanel = %RoomPanel
@onready var _palette: BuildPalette = %BuildPalette
@onready var _card: RoomCard = %RoomCard


func _ready() -> void:
	_levels.level_chosen.connect(_show_level)
	visibility_changed.connect(_on_visibility_changed)
	_plan.selection_changed.connect(_on_selection_changed)
	_panel.show_nothing()
	_ready_build()
	_setup_power()
	add_child(_messages)
	_panel.add_child(room_camera)
	_panel.move_child(room_camera, 0)
	room_camera.setup(_plan)
	_panel.add_child(_slots)
	_room_artefacts.visible = false
	_panel.add_child(_room_artefacts)
	_tabs.name = "Tabs"
	add_child(_tabs)
	_tabs.attach(_sub_tabs, _levels, _power, _build)
	BaseTableSetup.ready(self, _card, _mode_keys)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	_connect_build_events(true)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	_connect_build_events(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Reads the base of [param simulation]; starts on the Gate Room's level.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_defs = _room_defs()
	var base: BaseState = simulation.state.base
	_plan.show_base(base, _defs)
	_show_progress()
	_levels.show_levels(base.levels, _plan.level)
	_show_level(gate_level(base))
	_signature = signature(base)
	_setup_build()
	_power.setup(simulation)
	_messages.setup(_palette, simulation.state)
	_slots.setup(simulation)
	_room_artefacts.setup(simulation)
	_refresh_lab_note()


func get_default_focus() -> Control:
	return _plan


func get_title_key() -> StringName:
	return &"BASE_TITLE"


## Returns the plan, for tests.
func get_plan() -> BasePlan:
	return _plan


## Returns the selected room's staff slots, for tests.
func get_staff_slots() -> StaffSlots:
	return _slots


## Returns the selected storage room's artefacts (hidden for other rooms).
func get_room_artefacts() -> ArtefactPanel:
	return _room_artefacts


## Shows the artefacts of [param room] and those it could take, when it is a storage room.
func _show_room_artefacts(room: RoomState) -> void:
	var def: RoomDef = null if room == null else _def(room.def_id)
	_room_artefacts.visible = def != null and def.artefact_slots > 0
	if _room_artefacts.visible:
		_room_artefacts.room_filter = ArtefactRules.room_uid_of(room.id)
		_room_artefacts.refresh()


## Returns the selected-room panel, for tests.
func get_room_panel() -> RoomPanel:
	return _panel


## Returns the sub-tab bar, for tests.
func get_sub_tabs() -> BaseSubTabs:
	return _sub_tabs


func _unhandled_input(event: InputEvent) -> void:
	if room_camera.is_expanded() and event.is_action_pressed(&"ui_cancel"):
		room_camera.set_expanded(false)
		get_viewport().set_input_as_handled()
		return
	if is_visible_in_tree() and _tabs.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if _build_input(event):
		return
	var step: int = _level_step(event)
	if step == 0 or _simulation == null:
		return
	_show_level(_plan.level + step)
	get_viewport().set_input_as_handled()


## -1 for the level above (base_level_up), +1 for the one below (base_level_down), else 0.
static func _level_step(event: InputEvent) -> int:
	if InputActions.is_new_press(event, &"base_level_up"):
		return -1
	if InputActions.is_new_press(event, &"base_level_down"):
		return 1
	return 0


func _show_level(number: int) -> void:
	_plan.show_level(number)
	_levels.mark(_plan.level)
	_heading.text = tr(&"BASE_LEVEL_HEADING").format({"n": _plan.level})


func _refresh() -> void:
	if _simulation == null:
		return
	_show_progress()
	_levels.refresh()
	_heading.text = tr(&"BASE_LEVEL_HEADING").format({"n": _plan.level})
	_plan.queue_redraw()
	_on_selection_changed(_plan.selected())
	_refresh_build()
	_power.refresh()
	_refresh_lab_note()


func _on_tick_advanced(_tick: int) -> void:
	if _simulation == null or not is_visible_in_tree():
		return
	var now: int = signature(_simulation.state.base)
	if now == _signature:
		return
	_signature = now
	_refresh()


## Hands the sites', demolitions' and dig's progress (SiteProgress) to the plan and the level
## column; read on ticks and events only, never per frame.
func _show_progress() -> void:
	var state: GameState = _simulation.state
	_plan.show_progress(SiteProgress.for_rooms(state, state.base.rooms))
	_levels.show_dig(SiteProgress.of_dig(state))


## Returns the level of [param base]'s Gate Room, or its deepest level when there is none.
static func gate_level(base: BaseState) -> int:
	for room: RoomState in base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			return room.level
	return base.level_count


## Returns a cheap hash of what the view shows of [param base]: rooms, their ids, places,
## switches, and the work left to build, demolish or dig in steps of PROGRESS_STEP_TICKS (the
## progress bars move at most once per step).
static func signature(base: BaseState) -> int:
	var parts: Array = [base.rooms.size(), base.levels.size()]
	for room: RoomState in base.rooms:
		parts.append_array([room.id, room.level, room.origin, room.rotated])
		parts.append(ceili(float(room.build_ticks_left) / PROGRESS_STEP_TICKS))
		parts.append(ceili(float(room.demolish_ticks_left) / PROGRESS_STEP_TICKS))
		parts.append(int(room.powered_on))
	for level: LevelState in base.levels:
		parts.append(ceili(float(level.dig_ticks_left) / PROGRESS_STEP_TICKS))
	return hash(parts)


func _on_selection_changed(selected: StringName) -> void:
	_power.select(selected)
	if _simulation == null:
		return
	room_camera.show_room(selected)
	_slots.show_room(selected)
	room_camera.visible = false
	_slots.visible = false
	var room: RoomState = _simulation.state.base.find_room(selected)
	_show_room_artefacts(room)
	var def: RoomDef = null
	if room != null:
		def = _def(room.def_id)
	if def == null:
		_panel.show_nothing()
		_card.show_room(null, null)
		return
	var progress: SiteProgress = SiteProgress.of_room(_simulation.state, room)
	_panel.show_room(room, def, _simulation.state.unlocks, progress)
	_card.show_room(room, def)


static func _room_defs() -> Dictionary:
	var defs: Dictionary = {}
	for def: DefBase in Registry.get_all_of(RoomDef):
		defs[def.id] = def
	return defs


## The RoomDef with id [param def_id], or null.
func _def(def_id: StringName) -> RoomDef:
	var found: Variant = _defs.get(def_id)
	return found if found is RoomDef else null


# --- Power (card #141): the strip, the panel's switch and charge control, the energy layer.
# All of it lives in BaseViewPower; the view only attaches it and passes the selection on.


## Returns the power part of the tab, for tests.
func get_power() -> BaseViewPower:
	return _power


func _setup_power() -> void:
	_power.name = "Power"
	add_child(_power)
	_power.attach(_heading.get_parent() as Control, _plan, _panel)


# --- Building (card #140): palette, placement ghost, panel actions, dig -------------------


## Starts placing a Capacitor Bank for the Gate Room's button: shows the Gate Room's level,
## and puts the ghost on the nearest valid spot to the Gate Room (BaseSpots.bank_spot),
## centred, so one click builds it. With no valid spot the ghost still comes out, on the Gate
## Room, and the palette says why.
func place_capacitor_bank() -> void:
	if _simulation == null or _def(StartingBase.CAPACITOR_BANK_DEF) == null:
		return
	var base: BaseState = _simulation.state.base
	_show_level(gate_level(base))
	_sub_tabs.show_tab(BaseSubTabs.BUILD)
	var spot: Vector2i = BaseSpots.bank_spot(base, _defs)
	if spot != BaseSpots.NO_SPOT:
		_build.place_at(StartingBase.CAPACITOR_BANK_DEF, spot)
		return
	var gate: RoomState = BaseSpots.gate_room(base)
	_build.place_at(StartingBase.CAPACITOR_BANK_DEF, gate.origin if gate != null else Vector2i.ZERO)
	_palette.show_message(tr(&"BASE_BUILD_NO_BANK_SPOT").format({"n": gate_level(base)}))


## Returns the building controller, for tests.
func get_build() -> BaseBuild:
	return _build


## Returns the build palette, for tests.
func get_palette() -> BuildPalette:
	return _palette


func _ready_build() -> void:
	_build = BaseBuild.new(_plan, _palette, _panel)
	_plan.selection_changed.connect(_build.show_action)


func _setup_build() -> void:
	_build.setup(_simulation, _defs)


## Rebuilds the level column when a level was dug or dropped, then rereads the build controls.
func _refresh_build() -> void:
	var state: GameState = _simulation.state
	if state.base.levels.size() != _levels.level_count():
		_levels.show_levels(state.base.levels, _plan.level)
	_build.refresh()
	var dig: DigButton = _palette.get_dig_button()
	var next: int = state.base.level_count + 1
	var cost: String = ""
	if state.balance != null:
		cost = BaseTableSetup.short_money(DigLevelCommand.cost_k(state, next))
	_levels.show_next(DigButton.next_level(state), not dig.disabled, dig.get_reason(), cost)
	_tabs.show_sub_tab()


## Build, demolish, dig and money events redraw at once: while paused, commands apply
## immediately and no tick follows.
func _connect_build_events(on: bool) -> void:
	var signals: Array[Signal] = [
		EventBus.room_build_started,
		EventBus.room_built,
		EventBus.room_demolished,
		EventBus.level_dug,
		EventBus.budget_changed,
		EventBus.research_done,
	]
	for event: Signal in signals:
		if on:
			event.connect(_on_build_event)
		else:
			event.disconnect(_on_build_event)
	if on:
		EventBus.power_allocation_changed.connect(_on_power_changed)
	else:
		EventBus.power_allocation_changed.disconnect(_on_power_changed)


## A room switched on or off (a Workshop changes every site's and the dig's time left):
## rereads only the progress, the level column and the SELECTED panel, also while paused.
func _on_power_changed() -> void:
	if _simulation == null or not is_node_ready():
		return
	_show_progress()
	_levels.refresh()
	_on_selection_changed(_plan.selected())


## Ticks skip the tab while hidden, and research (an unlock) changes no part of the
## signature: showing the tab rereads everything (the "no N2 after the research" fix).
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_on_build_event()


func _on_build_event(_arg: Variant = null) -> void:
	if _simulation == null:
		return
	_signature = signature(_simulation.state.base)
	_refresh()


## (B) or Esc on the plan, while not placing, moves focus to the palette.
func _build_input(event: InputEvent) -> bool:
	if _simulation == null or not _plan.has_focus() or not event.is_action_pressed(&"ui_cancel"):
		return false
	if not _build.focus_palette():
		return false
	get_viewport().set_input_as_handled()
	return true


# --- Research (card #167): the palette's note on a second Research Lab ---------------------


## With a Research Lab already on the base (built or building), hovering or focusing the
## palette's Research Lab says "More labs hold more scientists." Building stays allowed.
func _refresh_lab_note() -> void:
	_palette.notes.erase(ResearchRules.LAB_DEF)
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == ResearchRules.LAB_DEF:
			_palette.notes[ResearchRules.LAB_DEF] = tr(&"RESEARCH_ONE_LAB_ENOUGH")
			return
