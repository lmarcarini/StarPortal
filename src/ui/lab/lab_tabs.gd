class_name LabTabs
extends Control
## The Lab's discipline tabs (interface-reference.md section 9, lab_tabs): one [LabTabKey]
## per open discipline, 222 px apart, the shown one amber, an amber lamp on each with NEW
## projects. A tab appears only when its discipline opens (ResearchRules.open_disciplines).
## Bible: docs/content/interface-reference.md section 9

## A tab was pressed.
signal discipline_chosen(discipline: StringName)

const PITCH: float = 222.0

var _keys: Array[LabTabKey] = []
var _shown: StringName = &""


func _init() -> void:
	name = &"LabTabs"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows a tab for each of [param state]'s open disciplines; keeps the keys when they stay.
func show_state(state: GameState) -> void:
	var open: Array[StringName] = ResearchRules.open_disciplines(state)
	if open != disciplines():
		_rebuild(open)
	for key: LabTabKey in _keys:
		key.has_new = LabTabs.has_new(state, key.discipline)
	mark(_shown)


## Lights [param discipline]'s tab.
func mark(discipline: StringName) -> void:
	_shown = discipline
	for key: LabTabKey in _keys:
		key.style = (
			RefPaint.KeyStyle.AMBER if key.discipline == discipline else RefPaint.KeyStyle.STEEL
		)


## The disciplines shown, in order.
func disciplines() -> Array[StringName]:
	var found: Array[StringName] = []
	for key: LabTabKey in _keys:
		found.append(key.discipline)
	return found


## The tab keys, in order.
func keys() -> Array[LabTabKey]:
	return _keys


## The key of [param discipline], or null.
func key_of(discipline: StringName) -> LabTabKey:
	for key: LabTabKey in _keys:
		if key.discipline == discipline:
			return key
	return null


## True when [param discipline] has a visible project not yet opened (NEW).
static func has_new(state: GameState, discipline: StringName) -> bool:
	for def: ResearchDef in ResearchRules.visible_projects(state, discipline):
		if LabText.status(state, def) == LabText.Status.NEW:
			return true
	return false


func _rebuild(open: Array[StringName]) -> void:
	for key: LabTabKey in _keys:
		remove_child(key)
		key.queue_free()
	_keys.clear()
	for index: int in open.size():
		var key: LabTabKey = LabTabKey.new()
		key.show_discipline(open[index])
		key.position = Vector2(index * PITCH, 4)
		key.pressed.connect(discipline_chosen.emit.bind(open[index]))
		add_child(key)
		_keys.append(key)
