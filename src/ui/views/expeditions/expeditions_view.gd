class_name ExpeditionsView
extends GameView
## The Expeditions tab (F7; docs/content/m3-beyond-the-ring.md section 7), available once
## Expeditions unlock (ExpeditionUnlock.is_unlocked): the [ExpeditionPlanSheet] on the left,
## the [ExpeditionTripPanel] (timeline, trip log, Recall team, past) in the middle and the
## [ExpeditionCheckInPanel] (latest check-in, injured) on the right. **Ready team** submits a
## [PlanExpeditionCommand] and **Recall team** a [RecallTeamCommand]; a refusal shows its
## reason. Send team and Signal T-1 are Ring actions in the Gate Room, not here. The D-pad
## moves, (A) opens a slot's roster or picks, (Y) readies the team. Reads state only, and
## rereads it on every expedition, world, staff and room event, on each day, on showing and on
## a locale change, so it stays right while paused.
## Bible: docs/content/m3-beyond-the-ring.md section 7

var _simulation: Simulation = null
var _available: bool = false

@onready var _sheet: ExpeditionPlanSheet = %Sheet
@onready var _trip: ExpeditionTripPanel = %Trip
@onready var _check_in: ExpeditionCheckInPanel = %CheckIn


func _ready() -> void:
	_sheet.ready_pressed.connect(ready_team)
	_trip.recall_pressed.connect(recall_team)
	visibility_changed.connect(_on_visibility_changed)


func _enter_tree() -> void:
	_connect_events(true)


func _exit_tree() -> void:
	_connect_events(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads [param simulation]'s expedition.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_available = false
	_update_availability()
	refresh()


func get_default_focus() -> Control:
	return _sheet.get_first_focus()


func get_title_key() -> StringName:
	return &"EXPEDITION_TITLE"


## True once Expeditions are unlocked.
func is_available() -> bool:
	return _available


## Returns the plan sheet, for tests.
func get_sheet() -> ExpeditionPlanSheet:
	return _sheet


## Returns the middle column, for tests.
func get_trip() -> ExpeditionTripPanel:
	return _trip


## Returns the right column, for tests.
func get_check_in() -> ExpeditionCheckInPanel:
	return _check_in


## Opens the sheet on [param world_id] (Plan expedition in the World Report).
func plan_world(world_id: StringName) -> void:
	refresh()
	_sheet.choose_world(world_id)


## Rereads everything from the simulation.
func refresh() -> void:
	if _simulation == null or not is_node_ready():
		return
	var state: GameState = _simulation.state
	_sheet.show_state(state)
	_trip.show_state(state)
	_check_in.show_state(state)


## Submits the sheet's plan; a refusal shows on the sheet.
func ready_team() -> void:
	if _simulation == null:
		return
	var result: CommandResult = _simulation.submit(_sheet.get_draft().to_command())
	refresh()
	if not result.is_ok:
		_sheet.show_refusal(ExpeditionText.refusal(result.error_code))


## Recalls the team; a refusal shows under the button.
func recall_team() -> void:
	if _simulation == null:
		return
	var result: CommandResult = _simulation.submit(RecallTeamCommand.new())
	refresh()
	if not result.is_ok:
		_trip.show_notice(ExpeditionText.refusal(result.error_code))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventJoypadButton:
		return
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button.pressed and not button.is_echo() and button.button_index == JOY_BUTTON_Y:
		_sheet.press_ready()
		get_viewport().set_input_as_handled()


func _update_availability() -> void:
	if _available or _simulation == null:
		return
	if ExpeditionUnlock.is_unlocked(_simulation.state):
		_available = true
		availability_changed.emit()


func _connect_events(on: bool) -> void:
	var signals: Array[Signal] = [
		EventBus.expedition_planned,
		EventBus.team_sent,
		EventBus.team_returned,
		EventBus.team_checked_in,
		EventBus.team_recalled,
		EventBus.check_in_missed,
		EventBus.rescue_signal_sent,
		EventBus.rescue_signal_failed,
		EventBus.member_deceased,
		EventBus.team_rescued,
		EventBus.team_lost,
		EventBus.world_status_changed,
		EventBus.world_fact_raised,
		EventBus.world_target_changed,
		EventBus.staff_changed,
		EventBus.staff_arrived,
		EventBus.soldier_lent,
		EventBus.staff_healed,
		EventBus.room_built,
		EventBus.room_demolished,
		EventBus.day_started,
	]
	for event: Signal in signals:
		if on:
			event.connect(_on_event)
		else:
			event.disconnect(_on_event)


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_update_availability()
	if is_visible_in_tree():
		refresh()


## Events are skipped while the tab is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
