class_name TeamReportScreen
extends Control
## The team report, full screen in the dialogue screen's frame: on the left the team leader's
## portrait and the name plate (the leader, the team); on the right the outcome as an icon
## and two words, the world's picture and name, the mission and the days out as icons, the
## team as face tiles (injuries on them), what came back as icons, then keys: the World
## Report, HOLDING when an object came back, and CLOSE. While it shows the clock is held
## (SimClock hold [constant HOLD]); CLOSE, Esc or (B) closes it and releases the hold.
## Bible: docs/content/interface-rethink.md section 4 (Teams come home), issue #478

## The World Report of [param world_id] was asked for.
signal world_requested(world_id: StringName)
## HOLDING was pressed.
signal holding_requested
## The screen closed.
signal closed

## The SimClock hold reason while the report shows.
const HOLD: StringName = &"team_report"
const _OUTCOME_KEYS: Array[String] = [
	"STATION_DEBRIEF_SUCCESS",
	"STATION_DEBRIEF_FAILED",
	"STATION_DEBRIEF_EARLY",
	"STATION_DEBRIEF_RESCUED",
	"STATION_DEBRIEF_LOST"
]
const _OUTCOME_ICONS: Array[StringName] = [&"surveyed", &"threat", &"clock", &"team", &"close"]
const _MISSION_ICONS: Array[StringName] = [&"probed", &"surveyed", &"canister"]

var _simulation: Simulation = null
var _debrief: DebriefRules.Debrief = null
var _holding_clock: bool = false
var _portrait: PortraitWindow = PortraitWindow.new()
var _plate: NamePlate = NamePlate.new()
var _right: VBoxContainer = VBoxContainer.new()
var _close: BigKey = BigKey.new()


func _init() -> void:
	name = &"TeamReport"
	visible = false
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	add_to_group(Wire.COVER_GROUP)
	var ground: ColorRect = ColorRect.new()
	ground.color = DialogueScreen.GROUND
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var body: HBoxContainer = HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	body.add_theme_constant_override(&"separation", 28)
	add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 12)
	body.add_child(left)
	_portrait.custom_minimum_size = Vector2(320, 320)
	left.add_child(_portrait)
	left.add_child(_plate)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override(&"separation", 18)
	body.add_child(_right)
	_close.name = "CloseKey"
	_close.text = "HW_KEY_CLOSE"
	_close.activated.connect(close)


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	if visible:
		close()
	_simulation = simulation
	_portrait.portrait_defs = simulation.state.portrait_defs


## Shows [param debrief] and holds the clock.
func open(debrief: DebriefRules.Debrief) -> void:
	if _simulation == null or debrief == null:
		return
	_debrief = debrief
	_render()
	show()
	if not _holding_clock:
		_holding_clock = true
		SimClock.hold(HOLD)
	_focus_close.call_deferred()


func _focus_close() -> void:
	if _close.is_visible_in_tree():
		_close.grab_focus()


## Keeps [param debrief] to open later, without showing it.
func keep(debrief: DebriefRules.Debrief) -> void:
	_debrief = debrief


## Closes the screen and releases the clock.
func close() -> void:
	hide()
	if _holding_clock:
		_holding_clock = false
		SimClock.release(HOLD)
	closed.emit()


## The debrief shown last, or null.
func get_debrief() -> DebriefRules.Debrief:
	return _debrief


## The CLOSE key.
func get_close_key() -> BigKey:
	return _close


## The key with [param icon] among the action keys, or null.
func get_action(icon: StringName) -> IconKey:
	for key: Node in _right.find_children("Action_*", "IconKey", true, false):
		if (key as IconKey).icon_id == icon:
			return key as IconKey
	return null


func _render() -> void:
	if _close.get_parent() != null:
		_close.get_parent().remove_child(_close)
	for child: Node in _right.get_children():
		_right.remove_child(child)
		child.queue_free()
	var state: GameState = _simulation.state
	var speaker: SpeakerDef = state.speaker_defs.get(TeamContactRules.LEADER_SPEAKER)
	_portrait.show_speaker(speaker, &"neutral" if _debrief.outcome < 2 else &"wary")
	var title: String = "" if speaker == null else tr(speaker.title_key)
	_plate.show_speaker(_debrief.leader, UiPalette.SELECT, title, "")
	_right.add_child(_head_row())
	_right.add_child(_world_row(state))
	_right.add_child(_faces_row())
	_right.add_child(_icon_row(_debrief.findings))
	_right.add_child(_actions_row())


func _head_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.add_child(_icon(_OUTCOME_ICONS[_debrief.outcome], ""))
	var title: Label = Label.new()
	title.name = "Outcome"
	title.theme_type_variation = &"HwStencil"
	title.add_theme_font_size_override(&"font_size", 34)
	title.text = _OUTCOME_KEYS[_debrief.outcome]
	row.add_child(title)
	return row


func _world_row(state: GameState) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	var thumb: WorldThumb = WorldThumb.new()
	thumb.custom_minimum_size = Vector2(220, 124)
	row.add_child(thumb)
	thumb.show_world(_debrief.world_id)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"HwStencil"
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = AddressBookText.name_of_world(_debrief.world_id, state)
	row.add_child(name_label)
	var mission: int = clampi(_debrief.objective, 0, _MISSION_ICONS.size() - 1)
	row.add_child(_icon(_MISSION_ICONS[mission], ""))
	if _debrief.days > 0:
		row.add_child(_icon(&"clock", str(_debrief.days)))
	return row


func _faces_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Faces"
	row.add_theme_constant_override(&"separation", 10)
	for person: PersonState in _debrief.people:
		var face: FaceTile = FaceTile.new()
		face.custom_minimum_size = Vector2(96, 112)
		row.add_child(face)
		face.show_person(person)
	return row


func _icon_row(ids: Array[StringName]) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	for id: StringName in ids:
		row.add_child(_icon(id, ""))
	return row


func _actions_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	var world: IconKey = _icon(&"gate", "")
	world.name = "Action_World"
	world.set_help("HW_ICON_GATE")
	world.focus_mode = Control.FOCUS_ALL
	world.pressed.connect(func() -> void: world_requested.emit(_debrief.world_id))
	world.visible = not _debrief.world_id.is_empty()
	row.add_child(world)
	if _debrief.brought_object:
		var holding: IconKey = _icon(&"crate", "")
		holding.name = "Action_Holding"
		holding.focus_mode = Control.FOCUS_ALL
		holding.pressed.connect(holding_requested.emit)
		row.add_child(holding)
	row.add_child(_close)
	return row


func _icon(id: StringName, badge: String) -> IconKey:
	var key: IconKey = IconKey.new()
	key.icon_id = id
	key.badge_text = badge
	key.focus_mode = Control.FOCUS_NONE
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.set_help("HW_ICON_" + String(id).to_upper())
	return key


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_close) and not _close.get_parent():
		_close.free()


func _exit_tree() -> void:
	if _holding_clock:
		_holding_clock = false
		SimClock.release(HOLD)
