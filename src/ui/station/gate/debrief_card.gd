class_name DebriefCard
extends PaperCard
## The debrief, once per return (or rescue, or loss): the outcome as an icon and two words,
## the world, the team as face tiles (injuries on them) and what they brought as icons. Opens
## at the Gate; never pauses; a click or Esc closes it. The last one can be reopened.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams come home)

const _OUTCOME_KEYS: Array[String] = [
	"STATION_DEBRIEF_SUCCESS",
	"STATION_DEBRIEF_FAILED",
	"STATION_DEBRIEF_EARLY",
	"STATION_DEBRIEF_RESCUED",
	"STATION_DEBRIEF_LOST"
]
const _OUTCOME_ICONS: Array[StringName] = [&"surveyed", &"threat", &"clock", &"team", &"close"]

var _simulation: Simulation = null
var _last: DebriefRules.Debrief = null
var _column: VBoxContainer = VBoxContainer.new()


func _ready() -> void:
	super()
	z_index = 6
	_column.add_theme_constant_override(&"separation", 8)
	add_child(_column)
	gui_input.connect(_on_input)
	hide()


func _enter_tree() -> void:
	EventBus.team_debrief.connect(_on_debrief)
	EventBus.team_rescued.connect(_on_rescued)
	EventBus.team_lost.connect(_on_lost)


func _exit_tree() -> void:
	EventBus.team_debrief.disconnect(_on_debrief)
	EventBus.team_rescued.disconnect(_on_rescued)
	EventBus.team_lost.disconnect(_on_lost)


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation


## Shows [param debrief].
func show_debrief(debrief: DebriefRules.Debrief) -> void:
	_last = debrief
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var head: HBoxContainer = HBoxContainer.new()
	_column.add_child(head)
	var outcome: IconKey = IconKey.new()
	outcome.icon_id = _OUTCOME_ICONS[debrief.outcome]
	outcome.focus_mode = Control.FOCUS_NONE
	head.add_child(outcome)
	var title: Label = Label.new()
	title.name = "Outcome"
	title.theme_type_variation = &"HwStencil"
	title.add_theme_color_override(&"font_color", UiThemeHardware.INK)
	title.text = _OUTCOME_KEYS[debrief.outcome]
	head.add_child(title)
	var faces: HBoxContainer = HBoxContainer.new()
	_column.add_child(faces)
	for person: PersonState in debrief.people:
		var face: FaceTile = FaceTile.new()
		faces.add_child(face)
		face.show_person(person)
	var finds: HBoxContainer = HBoxContainer.new()
	_column.add_child(finds)
	for id: StringName in debrief.findings:
		var key: IconKey = IconKey.new()
		key.icon_id = id
		finds.add_child(key)
		key.set_help("HW_ICON_" + String(id).to_upper())
	show()
	reset_size()


## The debrief shown last, or null.
func get_last() -> DebriefRules.Debrief:
	return _last


## Opens the last debrief again.
func reopen() -> void:
	if _last != null:
		show_debrief(_last)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _on_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		hide()


func _on_debrief(world: StringName, summary: Dictionary) -> void:
	if _simulation != null:
		show_debrief(DebriefRules.of_return(_simulation.state, world, summary))


func _on_rescued(world: StringName, _survivors: int) -> void:
	if _simulation != null:
		show_debrief(DebriefRules.of_end(world, false))


func _on_lost(world: StringName, _reason: StringName) -> void:
	if _simulation != null:
		show_debrief(DebriefRules.of_end(world, true))
