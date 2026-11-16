class_name ClueClip
extends PaperCard
## The clue clipped beside the alien panel: one received document at a time, shown by the
## Archive's reader, with keys to swap to the previous or next document without leaving.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

const _READER: PackedScene = preload("res://src/ui/archive/document_reader.tscn")

var _simulation: Simulation = null
var _index: int = -1
var _reader: DocumentReader = null
var _prev: IconKey = IconKey.new()
var _next: IconKey = IconKey.new()


func _ready() -> void:
	super()
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
	var keys: HBoxContainer = HBoxContainer.new()
	column.add_child(keys)
	_prev.name = "PrevClue"
	_prev.icon_id = &"prev"
	_prev.set_help("HW_ICON_PREV")
	_prev.pressed.connect(step.bind(-1))
	keys.add_child(_prev)
	_next.name = "NextClue"
	_next.icon_id = &"next"
	_next.set_help("HW_ICON_NEXT")
	_next.pressed.connect(step.bind(1))
	keys.add_child(_next)
	_reader = _READER.instantiate() as DocumentReader
	_reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_reader)
	_reader.get_close_button().visible = false
	_reader.get_read_with_button().visible = false


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
	if _reader == null:
		return
	var id: StringName = get_document_id()
	if id.is_empty():
		_reader.clear()
		return
	var tick: int = _simulation.state.archive.received_tick.get(id, 0)
	_reader.show_document(id, Registry.get_def(id) as DocumentDef, tick)
