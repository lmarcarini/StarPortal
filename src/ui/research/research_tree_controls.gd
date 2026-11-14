class_name ResearchTreeControls
extends HBoxContainer
## The bar over the research tree: filter buttons (All, Available, Done, Locked), a search box
## and zoom buttons. It only reports what the player picked; ResearchBoard applies it.
## Bible: docs/content/m4-core-systems.md section 7 (5)

## Emitted when the filter, the search text or the zoom changes.
signal changed
## Emitted when the zoom buttons are pressed, with the factor.
signal zoom_requested(factor: float)

## Factor of one zoom step.
const ZOOM_STEP: float = 1.25
const _FILTER_KEYS: Array[StringName] = [
	&"RESEARCH_FILTER_ALL",
	&"RESEARCH_FILTER_AVAILABLE",
	&"RESEARCH_FILTER_DONE",
	&"RESEARCH_FILTER_LOCKED",
]

var _filter: int = ResearchTree.Filter.ALL
var _buttons: Array[Button] = []
var _search := LineEdit.new()


func _init() -> void:
	var group := ButtonGroup.new()
	for index: int in _FILTER_KEYS.size():
		var button := Button.new()
		button.text = _FILTER_KEYS[index]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = index == 0
		button.pressed.connect(set_filter.bind(index))
		_buttons.append(button)
		add_child(button)
	_search.placeholder_text = &"RESEARCH_SEARCH"
	_search.custom_minimum_size = Vector2(200, 0)
	_search.text_changed.connect(func(_text: String) -> void: changed.emit())
	add_child(_search)
	for pair: Array in [["-", 1.0 / ZOOM_STEP], ["+", ZOOM_STEP]]:
		var zoom := Button.new()
		zoom.text = pair[0]
		var factor: float = pair[1]
		zoom.pressed.connect(zoom_requested.emit.bind(factor))
		add_child(zoom)


## The chosen filter (ResearchTree.Filter).
func get_filter() -> ResearchTree.Filter:
	return _filter as ResearchTree.Filter


## Chooses filter [param index] (ResearchTree.Filter).
func set_filter(index: int) -> void:
	_filter = index
	_buttons[index].set_pressed_no_signal(true)
	changed.emit()


## The search text.
func get_search() -> String:
	return _search.text


## Sets the search text.
func set_search(text: String) -> void:
	_search.text = text
	changed.emit()
