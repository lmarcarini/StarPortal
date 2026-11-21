class_name ClueClip
extends PaperCard
## The clue clipped beside the alien panel: one received document at a time on off-white
## paper under a steel clip, typed in the data face, shown by the Archive's reader (long ones
## scroll inside it), with keys to swap to the previous or next document without leaving.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## The clipped document changed (another one shown).
signal document_changed

const _READER: PackedScene = preload("res://src/ui/archive/document_reader.tscn")
const _TYPE_FONT: Font = preload("res://art/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf")
## The steel clip at the top of the board, in pixels.
const CLIP_SIZE: Vector2 = Vector2(140.0, 30.0)
const CLIP_DARK: Color = Color("#3d4043")

var _simulation: Simulation = null
var _index: int = -1
var _reader: DocumentReader = null
var _prev: IconKey = IconKey.new()
var _next: IconKey = IconKey.new()


func _ready() -> void:
	super()
	var paper: StyleBoxFlat = StyleBoxFlat.new()
	paper.bg_color = RefPaint.PAPER
	paper.set_content_margin_all(18.0)
	paper.set_border_width_all(1)
	paper.border_color = Color8(120, 112, 90)
	paper.shadow_color = Color(0, 0, 0, 0.85)
	paper.shadow_size = 1
	paper.shadow_offset = Vector2(6, 8)
	add_theme_stylebox_override(&"panel", paper)
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
	var under_clip: Control = Control.new()
	under_clip.custom_minimum_size.y = CLIP_SIZE.y * 0.6
	column.add_child(under_clip)
	var keys: HBoxContainer = HBoxContainer.new()
	column.add_child(keys)
	_prev.name = "PrevClue"
	_prev.icon_id = &"prev"
	_prev.look = IconKey.Look.STEEL
	_prev.set_help("HW_ICON_PREV")
	_prev.pressed.connect(step.bind(-1))
	keys.add_child(_prev)
	_next.name = "NextClue"
	_next.icon_id = &"next"
	_next.look = IconKey.Look.STEEL
	_next.set_help("HW_ICON_NEXT")
	_next.pressed.connect(step.bind(1))
	keys.add_child(_next)
	_reader = _READER.instantiate() as DocumentReader
	_reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_reader)
	_reader.get_close_button().visible = false
	_reader.get_read_with_button().visible = false
	_type_on_paper(_reader)


## Paper look for [param reader]: no panel of its own, ink text in the typewriter face.
static func _type_on_paper(reader: DocumentReader) -> void:
	reader.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var paper: Theme = Theme.new()
	paper.set_color(&"font_color", &"Label", UiThemeHardware.INK)
	paper.set_color(&"default_color", &"RichTextLabel", UiThemeHardware.INK)
	paper.set_font(&"normal_font", &"RichTextLabel", _TYPE_FONT)
	paper.set_font(&"font", &"Label", _TYPE_FONT)
	paper.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	paper.set_stylebox(&"panel", &"PanelContainer", StyleBoxEmpty.new())
	reader.theme = paper


func _draw() -> void:
	var at: Vector2 = Vector2((size.x - CLIP_SIZE.x) * 0.5, -CLIP_SIZE.y * 0.4)
	RefPaint.steel_plate(self, Rect2(at, CLIP_SIZE), false, false)
	draw_circle(at + Vector2(CLIP_SIZE.x * 0.5, CLIP_SIZE.y * 0.35), 5.0, CLIP_DARK)


## Reads [param simulation]'s received documents; keeps the shown one if still received.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	var ids: Array[StringName] = _documents()
	if _index < 0 or _index >= ids.size():
		_index = ids.size() - 1
	_show()


## Shows the document [param delta] places on (wrapping).
func step(delta: int) -> void:
	var ids: Array[StringName] = _documents()
	if ids.is_empty():
		return
	_index = posmod(_index + delta, ids.size())
	_show()


## The document shown, or &"" for none.
func get_document_id() -> StringName:
	var ids: Array[StringName] = _documents()
	if _index < 0 or _index >= ids.size():
		return &""
	return ids[_index]


func _documents() -> Array[StringName]:
	var out: Array[StringName] = []
	if _simulation == null:
		return out
	for id: StringName in _simulation.state.archive.received:
		if Registry.get_def(id) is DocumentDef:
			out.append(id)
	return out


func _show() -> void:
	document_changed.emit()
	if _reader == null:
		return
	var id: StringName = get_document_id()
	if id.is_empty():
		_reader.clear()
		return
	var tick: int = _simulation.state.archive.received_tick.get(id, 0)
	_reader.show_document(id, Registry.get_def(id) as DocumentDef, tick)
