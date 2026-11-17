class_name MissionSheet
extends PaperCard
## The mission sheet (interface-reference.md section 5, mission_sheet): paper, 336 x 352,
## opened above the send rail clear of the Ring by TEAM: the title, the mission as three
## 96 x 78 paper keys (Survey, Recover; Contact greyed), the Recover target as small keys,
## the team as four 68 x 68 faces (tap one to swap to the next fit person of that slot), the
## days, and the GO hazard key (160 x 68), which submits
## PlanExpeditionCommand then SendTeamCommand. Prefilled by [MissionDefaults]. A refusal shows
## as a warning icon beside the team with the reason on its hover card.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams)

## GO sent the team (or, from a mission order, was accepted).
signal sent

## Sheet size, in pixels.
const SIZE: Vector2 = Vector2(336, 352)

var _simulation: Simulation = null
var _draft: ExpeditionPlanDraft = null
var _order_address: GateAddress = null
var _missions: HBoxContainer = HBoxContainer.new()
var _targets: HBoxContainer = HBoxContainer.new()
var _faces: HBoxContainer = HBoxContainer.new()
var _warning: IconKey = IconKey.new()
var _go: BigKey = BigKey.new()
var _body: Control = Control.new()


func _ready() -> void:
	super()
	z_index = 6
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	custom_minimum_size = SIZE
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_paper)
	add_child(_body)
	var rows: Dictionary[HBoxContainer, Vector2] = {
		_missions: Vector2(16, 54), _faces: Vector2(16, 148), _targets: Vector2(130, 222)
	}
	for row: HBoxContainer in rows:
		row.add_theme_constant_override(&"separation", 8 if row == _missions else 10)
		row.position = rows[row]
		_body.add_child(row)
	_warning.name = "Warning"
	_warning.icon_id = &"threat"
	_warning.look = IconKey.Look.PAPER
	_warning.position = Vector2(SIZE.x - 232, SIZE.y - 74)
	_body.add_child(_warning)
	_warning.custom_minimum_size = Vector2(44, 44)
	_go.name = "Go"
	_go.text = "HW_KEY_GO"
	_go.key_style = BigKey.KeyStyle.HAZARD
	_go.label_size = 36
	_go.activated.connect(go)
	_body.add_child(_go)
	_go.custom_minimum_size = Vector2.ZERO
	_go.position = Vector2(SIZE.x - 176, SIZE.y - 84)
	_go.size = Vector2(160, 68)
	hide()


func _draw_paper() -> void:
	RefPaint.paper(_body, Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0))
	if _draft == null or _simulation == null:
		return
	var world: String = AddressBookText.name_of_world(_draft.world_id, _simulation.state)
	var title: String = tr(&"STATION_MISSION_TITLE").format({"world": world.to_upper()})
	RefText.make(RefText.LABEL, 26, RefPaint.INK, 3.0).draw(_body, Vector2(16, 14), title)
	var days: String = str(ExpeditionState.OBJECTIVE_DAYS[_draft.objective])
	RefText.make(RefText.MONO_BOLD, 44, RefPaint.INK).draw(_body, Vector2(16, 262), days, "lm")
	var unit: RefText = RefText.make(RefText.LABEL, 18, Color8(90, 84, 66), 2.0)
	unit.draw(_body, Vector2(52, 266), tr(&"STATION_DAYS"), "lm")


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	hide()


## Opens the sheet for [param world], prefilled. With [param order_address] GO orders the
## mission from a closed gate (dial, send, close) instead of sending through the open one.
func open_for(world: StringName, order_address: GateAddress = null) -> void:
	if _simulation == null:
		return
	_order_address = order_address
	_draft = MissionDefaults.draft_for(_simulation.state, world)
	show()
	_render()
	_go.grab_focus.call_deferred()


## Closes the sheet without sending (Esc, (B), the wormhole closing, the alien panel).
func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## True when the sheet orders a mission from a closed gate (not a send through the open one).
func is_order() -> bool:
	return _order_address != null


## The draft shown.
func get_draft() -> ExpeditionPlanDraft:
	return _draft


## Chooses [param objective] (with the first target for a Recover).
func choose(objective: ExpeditionState.Objective, target: StringName = &"") -> void:
	if target.is_empty() and objective == ExpeditionState.Objective.RECOVER:
		var targets: Array[WorldTarget] = ExpeditionPlanDraft.targets(
			_simulation.state, _draft.world_id
		)
		target = targets[0].id if not targets.is_empty() else &""
	_draft.choose_objective(objective, target)
	_render()


## Swaps slot [param slot] to the next fit person.
func swap(slot: String) -> void:
	var state: GameState = _simulation.state
	var options: Array[PersonState] = ExpeditionPlanDraft.candidates(state, slot).filter(
		func(p: PersonState) -> bool: return MissionDefaults.is_fit(state, p, slot)
	)
	if options.is_empty():
		return
	var at: int = -1
	for i: int in options.size():
		var current: StringName = _draft.team.get(slot, &"")
		if options[i].id == current:
			at = i
	_draft.choose_member(slot, options[(at + 1) % options.size()].id)
	_render()


## The reason GO is refused now, or &"".
func reason() -> StringName:
	if _draft == null:
		return &"no_plan"
	var error: StringName = _draft.error(_simulation.state)
	if error != &"" and not (_order_address != null and error == ExpeditionRules.NO_WORMHOLE):
		return error
	if _order_address != null:
		return MissionOrderRules.refusal(_simulation.state, _order_address, false)
	if _simulation.state.gate.connected_world_id != _draft.world_id:
		return ExpeditionRules.NO_WORMHOLE
	return &""


## GO: readies the plan and sends the team through the open wormhole.
func go() -> void:
	if _simulation == null or _draft == null:
		return
	var result: CommandResult = null
	if _order_address != null:
		result = _simulation.submit(OrderMissionCommand.create(_order_address, _draft.to_command()))
	else:
		result = _simulation.submit(_draft.to_command())
		if result.is_ok:
			result = _simulation.submit(SendTeamCommand.new())
	if not result.is_ok:
		_show_reason(result.error_code)
		return
	hide()
	sent.emit()


func _render() -> void:
	if _draft == null:
		return
	_render_missions()
	_render_targets()
	_render_faces()
	var why: StringName = reason()
	_show_reason(why)
	_body.queue_redraw()


func _render_missions() -> void:
	_clear(_missions)
	var objectives: Array[ExpeditionState.Objective] = [
		ExpeditionState.Objective.SURVEY, ExpeditionState.Objective.RECOVER
	]
	var icons: Array[StringName] = [&"eye", &"canister"]
	var names: Array[String] = ["SURVEY", "RECOVER"]
	var helps: Array[String] = ["STATION_MISSION_SURVEYED", "STATION_MISSION_CANISTER"]
	for i: int in objectives.size():
		var key: IconKey = _key(_missions, icons[i], helps[i])
		key.label = "STATION_MISSION_KEY_" + names[i]
		var active: bool = _draft.objective == objectives[i]
		key.set_state(IconKey.KeyState.ACTIVE if active else IconKey.KeyState.READY)
		key.pressed.connect(choose.bind(objectives[i]))
	var contact: IconKey = _key(_missions, &"hail", "STATION_MISSION_CONTACT")
	contact.label = "STATION_MISSION_KEY_CONTACT"
	contact.set_state(IconKey.KeyState.UNAVAILABLE)


func _render_targets() -> void:
	_clear(_targets)
	_targets.visible = _draft.objective == ExpeditionState.Objective.RECOVER
	for target: WorldTarget in ExpeditionPlanDraft.targets(_simulation.state, _draft.world_id):
		var key: IconKey = _key(_targets, &"base", String(target.name_key))
		key.custom_minimum_size = Vector2(44, 44)
		key.set_state(
			IconKey.KeyState.ACTIVE if target.id == _draft.target_id else IconKey.KeyState.READY
		)
		key.pressed.connect(choose.bind(ExpeditionState.Objective.RECOVER, target.id))


func _render_faces() -> void:
	_clear(_faces)
	for slot: String in ExpeditionState.SLOTS:
		var face: FaceTile = FaceTile.new()
		face.name = "Face_" + slot
		face.custom_minimum_size = Vector2(68, 68)
		var person_id: StringName = _draft.team.get(slot, &"")
		var person: PersonState = _simulation.state.staff.find_person(person_id)
		face.show_person(person)
		face.pressed.connect(swap.bind(slot))
		_faces.add_child(face)


func _show_reason(code: StringName) -> void:
	_warning.visible = code != &""
	_go.disabled = code != &""
	if code != &"":
		_warning.set_help(String(SendRailRules.reason_key(code)))


func _key(row: HBoxContainer, icon: StringName, help: String) -> IconKey:
	var key: IconKey = IconKey.new()
	key.icon_id = icon
	key.look = IconKey.Look.PAPER
	key.label_size = 16
	row.add_child(key)
	key.custom_minimum_size = Vector2(96, 78)
	key.set_help(help)
	return key


static func _clear(row: HBoxContainer) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
