class_name InstallList
extends VBoxContainer
## The INSTALLATIONS section of the room panel (M4c-19): each installation on the room (built,
## or its progress while it is a site) with Remove and the refund; then Install… entries for
## what fits this room, with price and time, greyed with the reason when not available
## (locked ones name their research). Submits InstallCommand / RemoveInstallationCommand.
## Bible: docs/content/m4c-incursions.md section 6

var _room_id: StringName = &""
var _title := Label.new()


func _init() -> void:
	name = &"InstallList"
	visible = false
	_title.text = &"INSTALL_TITLE"
	_title.add_theme_font_size_override(&"font_size", 16)
	_title.add_theme_color_override(&"font_color", RefPaint.DIM)
	_title.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL_MEDIUM, 0, RefPaint.DIM, 2.0).get_font()
	)
	add_child(_title)


func _enter_tree() -> void:
	EventBus.installation_changed.connect(_on_changed)
	EventBus.day_started.connect(_on_changed)


func _exit_tree() -> void:
	EventBus.installation_changed.disconnect(_on_changed)
	EventBus.day_started.disconnect(_on_changed)


func _on_changed(_value: Variant = null) -> void:
	if visible:
		refresh()


## Shows the installations of [param room] (null hides the section).
func show_room(room: RoomState) -> void:
	_room_id = room.id if room != null else &""
	refresh()


## Rereads the room from the running simulation.
func refresh() -> void:
	for child: Node in get_children():
		if child != _title:
			remove_child(child)
			child.queue_free()
	var simulation: Simulation = SimClock.simulation
	var room: RoomState = null
	if simulation != null and not _room_id.is_empty():
		room = simulation.state.base.find_room(_room_id)
	var offers: Array[InstallationDef] = []
	if room != null:
		offers = fitting(simulation.state, room)
	visible = room != null and (not room.installations.is_empty() or not offers.is_empty())
	if not visible:
		return
	for item: InstallationState in room.installations:
		_add_installed(simulation.state, item)
	for def: InstallationDef in offers:
		_add_offer(simulation.state, room, def)


## The installation defs of [param state] that fit [param room] and it has room for, by id.
static func fitting(state: GameState, room: RoomState) -> Array[InstallationDef]:
	var found: Array[InstallationDef] = []
	var ids: Array = state.installation_defs.keys()
	IdOrder.sort(ids)
	for id: StringName in ids:
		var def: InstallationDef = state.installation_defs[id]
		if not def.fits_room(room.def_id):
			continue
		if InstallationRules.count(room.installations, id) < def.max_per_host:
			found.append(def)
	return found


## The button text and refusal for installing [param def] on [param room].
static func offer_text(state: GameState, room: RoomState, def: InstallationDef) -> Array[String]:
	var text: String = (
		TranslationServer
		. translate(&"INSTALL_OFFER")
		. format(
			{
				"name": TranslationServer.translate(def.name_key),
				"cost": MoneyLabel.format_k(def.cost_k),
				"time": BuildText.duration(def.build_ticks),
			}
		)
	)
	var check: CommandResult = InstallationRules.can_install(state, def.id, room)
	var reason: String = ""
	if check.error_code == &"not_researched":
		var project: ResearchDef = state.research_defs.get(def.requires_research)
		var project_name: String = (
			TranslationServer.translate(project.name_key)
			if project != null
			else String(def.requires_research)
		)
		reason = TranslationServer.translate(&"INSTALL_LOCKED").format({"name": project_name})
	elif not check.is_ok:
		reason = BuildText.reason(check, state, def.cost_k)
	return [text, reason]


func _add_installed(state: GameState, item: InstallationState) -> void:
	var def: InstallationDef = state.installation_defs.get(item.def)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var name_text: String = tr(def.name_key) if def != null else String(item.def)
	if not item.is_built() and def != null:
		var done: int = 100 - item.build_ticks_left * 100 / maxi(1, def.build_ticks)
		name_text = tr(&"INSTALL_BUILDING").format({"name": name_text, "percent": done})
	label.text = name_text
	row.add_child(label)
	var remove := RefKey.new()
	remove.label = &"INSTALL_REMOVE_KEY"
	remove.label_size = 16
	remove.custom_minimum_size = Vector2(110, 40)
	remove.text = tr(&"INSTALL_REMOVE").format(
		{"refund": MoneyLabel.format_k(InstallationRules.refund_k(item))}
	)
	remove.set_help(remove.text)
	remove.pressed.connect(_submit.bind(RemoveInstallationCommand.create(_room_id, item.def)))
	row.add_child(remove)
	add_child(row)


func _add_offer(state: GameState, room: RoomState, def: InstallationDef) -> void:
	var texts: Array[String] = offer_text(state, room, def)
	var button := RefKey.new()
	button.label = &"INSTALL_KEY"
	button.label_size = 18
	button.custom_minimum_size = Vector2(160, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.text = texts[0]
	button.disabled = not texts[1].is_empty()
	button.set_help(texts[0] if texts[1].is_empty() else "%s\n%s" % [texts[0], texts[1]])
	button.pressed.connect(_submit.bind(InstallCommand.create(_room_id, def.id)))
	add_child(button)


func _submit(command: Command) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation != null:
		simulation.submit(command)
	refresh()
