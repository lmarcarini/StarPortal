class_name MissionSheet
extends PaperCard
## The mission sheet, a paper card opened in place by TEAM on the send rail: the mission as
## icon keys (Survey, Recover; Contact greyed), the Recover target as icon keys, the team as
## four face tiles (tap one to swap to the next fit person of that slot) and GO, which submits
## PlanExpeditionCommand then SendTeamCommand. Prefilled by [MissionDefaults]. A refusal shows
## as a warning icon beside the team with the reason on its hover card.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams)

## GO sent the team (or, from a mission order, was accepted).
signal sent

var _simulation: Simulation = null
var _draft: ExpeditionPlanDraft = null
var _order_address: GateAddress = null
var _missions: HBoxContainer = HBoxContainer.new()
var _targets: HBoxContainer = HBoxContainer.new()
var _faces: HBoxContainer = HBoxContainer.new()
var _warning: IconKey = IconKey.new()
var _go: BigKey = BigKey.new()


func _ready() -> void:
	super()
	z_index = 6
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)
	for row: HBoxContainer in [_missions, _targets, _faces]:
		row.add_theme_constant_override(&"separation", 8)
		column.add_child(row)
	_warning.name = "Warning"
	_warning.icon_id = &"threat"
	_faces.add_child(_warning)
	_go.name = "Go"
	_go.text = "HW_KEY_GO"
	_go.key_style = BigKey.KeyStyle.HAZARD
	_go.activated.connect(go)
	column.add_child(_go)
	hide()


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


func _render_missions() -> void:
	_clear(_missions)
	var objectives: Array[ExpeditionState.Objective] = [
		ExpeditionState.Objective.SURVEY, ExpeditionState.Objective.RECOVER
	]
	var icons: Array[StringName] = [&"surveyed", &"canister"]
	for i: int in objectives.size():
		var key: IconKey = _key(
			_missions, icons[i], "STATION_MISSION_" + String(icons[i]).to_upper()
		)
		var active: bool = _draft.objective == objectives[i]
		key.set_state(IconKey.KeyState.ACTIVE if active else IconKey.KeyState.READY)
		key.pressed.connect(choose.bind(objectives[i]))
	var contact: IconKey = _key(_missions, &"people", "STATION_MISSION_CONTACT")
	contact.set_state(IconKey.KeyState.UNAVAILABLE)


func _render_targets() -> void:
	_clear(_targets)
	_targets.visible = _draft.objective == ExpeditionState.Objective.RECOVER
	for target: WorldTarget in ExpeditionPlanDraft.targets(_simulation.state, _draft.world_id):
		var key: IconKey = _key(_targets, &"base", String(target.name_key))
		key.set_state(
			IconKey.KeyState.ACTIVE if target.id == _draft.target_id else IconKey.KeyState.READY
		)
		key.pressed.connect(choose.bind(ExpeditionState.Objective.RECOVER, target.id))


func _render_faces() -> void:
	for child: Node in _faces.get_children():
		if child != _warning:
			_faces.remove_child(child)
			child.queue_free()
	for slot: String in ExpeditionState.SLOTS:
		var face: FaceTile = FaceTile.new()
		face.name = "Face_" + slot
		var person_id: StringName = _draft.team.get(slot, &"")
		var person: PersonState = _simulation.state.staff.find_person(person_id)
		face.show_person(person)
		face.pressed.connect(swap.bind(slot))
		_faces.add_child(face)
	_faces.move_child(_warning, -1)


func _show_reason(code: StringName) -> void:
	_warning.visible = code != &""
	_go.disabled = code != &""
	if code != &"":
		_warning.set_help(String(SendRailRules.reason_key(code)))


func _key(row: HBoxContainer, icon: StringName, help: String) -> IconKey:
	var key: IconKey = IconKey.new()
	key.icon_id = icon
	row.add_child(key)
	key.set_help(help)
	return key


static func _clear(row: HBoxContainer) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
