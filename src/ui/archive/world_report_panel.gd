class_name WorldReportPanel
extends PanelContainer
## One world's World Report: its name and state, its address when the Address Book holds it,
## then every report fact as the player may see it (unknown, a range or a value) with its
## confidence and source, and **Plan expedition**: enabled once Expeditions unlock on a world
## Probed or beyond, it emits [signal plan_requested] (the switcher opens the Expeditions tab
## with the world chosen); otherwise it is greyed with the reason. Values come only through WorldReportText, which reads
## WorldReportRules. Reads state only.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields), section 7
## (World Report sketch; gamepad)

## Emitted when **Plan expedition** is pressed, with the world shown.
signal plan_requested(world_id: StringName)

## Facts in the order the report lists them.
const FACT_ORDER: Array[WorldReport.Fact] = [
	WorldReport.Fact.THREAT,
	WorldReport.Fact.ATMOSPHERE,
	WorldReport.Fact.TEMPERATURE,
	WorldReport.Fact.RADIATION,
	WorldReport.Fact.BIOHAZARD,
	WorldReport.Fact.LIFE,
	WorldReport.Fact.STRUCTURES,
	WorldReport.Fact.TARGETS,
]
const _STRIP_SCENE: PackedScene = preload("res://src/ui/gate_room/address_strip.tscn")
const _TITLE_SIZE: int = 20
const _NOTE_SIZE: int = 13

var _world_id: StringName = &""
var _title: Label = Label.new()
var _status: Label = Label.new()
var _empty: Label = Label.new()
var _address_row: HBoxContainer = HBoxContainer.new()
var _strip: AddressStrip = null
var _grid: GridContainer = GridContainer.new()
var _values: Dictionary[WorldReport.Fact, Label] = {}
var _notes: Dictionary[WorldReport.Fact, Label] = {}
var _plan: Button = Button.new()
var _description: Label = Label.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 8)
	add_child(layout)
	var header := HBoxContainer.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override(&"font_size", _TITLE_SIZE)
	header.add_child(_title)
	header.add_child(_status)
	layout.add_child(header)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.text = &"WORLD_REPORT_EMPTY"
	layout.add_child(_empty)
	layout.add_child(_address_row)
	_grid.columns = 3
	_grid.add_theme_constant_override(&"h_separation", 12)
	layout.add_child(_grid)
	_description.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_description)
	_plan.text = &"WORLD_PLAN_EXPEDITION"
	_plan.disabled = true
	_plan.tooltip_text = &"WORLD_PLAN_EXPEDITION_LATER"
	_plan.pressed.connect(func() -> void: plan_requested.emit(_world_id))
	_plan.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(_plan)
	_build_rows()


func _ready() -> void:
	_strip = _STRIP_SCENE.instantiate() as AddressStrip
	var label := Label.new()
	label.text = &"WORLD_ADDRESS"
	_address_row.add_child(label)
	_address_row.add_child(_strip)
	clear()


## Shows the report of [param world_id] from [param state].
func show_world(world_id: StringName, state: GameState) -> void:
	_world_id = world_id
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts == null:
		clear()
		return
	var report: WorldReport = state.worlds.report_of(world_id)
	_title.text = AddressBookText.name_of_world(world_id, state)
	_status.text = WorldReportText.status_name(state.worlds.status_of(world_id))
	for fact: WorldReport.Fact in FACT_ORDER:
		_values[fact].text = WorldReportText.value(facts, report, fact)
		_notes[fact].text = WorldReportText.note(report, fact)
	_description.text = MothReportText.report_lines(facts, report)
	var address: GateAddress = WorldReportText.address_of(world_id, state)
	if is_node_ready():
		_strip.setup(address)
	_address_row.visible = address != null
	_show_plan(world_id, state)
	_set_shown(true)


## Shows no world, only the hint to pick one.
func clear() -> void:
	_world_id = &""
	_title.text = ""
	_status.text = ""
	_address_row.visible = false
	_description.text = ""
	_set_shown(false)


## Returns the world shown, or &"" when none is.
func get_world_id() -> StringName:
	return _world_id


## Returns the shown value of [param fact].
func get_value_text(fact: WorldReport.Fact) -> String:
	return _values[fact].text


## Returns the confidence and source shown for [param fact], "" while unknown.
func get_note_text(fact: WorldReport.Fact) -> String:
	return _notes[fact].text


## Returns the label with the report's description lines.
func get_description_label() -> Label:
	return _description


## Returns the address strip.
func get_address_strip() -> AddressStrip:
	return _strip


## Returns the **Plan expedition** button.
func get_plan_button() -> Button:
	return _plan


func _build_rows() -> void:
	for fact: WorldReport.Fact in FACT_ORDER:
		var label := Label.new()
		label.text = WorldReportText.FACT_KEYS[fact]
		_grid.add_child(label)
		var value := Label.new()
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.custom_minimum_size.x = 160
		_grid.add_child(value)
		_values[fact] = value
		var note := Label.new()
		note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		note.add_theme_font_size_override(&"font_size", _NOTE_SIZE)
		_grid.add_child(note)
		_notes[fact] = note
	for label: Label in [_title, _status]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _set_shown(is_shown: bool) -> void:
	_empty.visible = not is_shown
	_grid.visible = is_shown
	_description.visible = is_shown
	_plan.visible = is_shown


## Enables Plan expedition once Expeditions unlock on a world Probed or beyond; else greys it
## with the reason.
func _show_plan(world_id: StringName, state: GameState) -> void:
	var tooltip: StringName = &""
	if not ExpeditionUnlock.is_unlocked(state):
		tooltip = &"WORLD_PLAN_EXPEDITION_LATER"
	elif not state.worlds.has_reached(world_id, WorldsState.WorldStatus.PROBED):
		tooltip = &"WORLD_PLAN_EXPEDITION_NOT_PROBED"
	_plan.disabled = not tooltip.is_empty()
	_plan.tooltip_text = tooltip
