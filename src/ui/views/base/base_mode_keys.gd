class_name BaseModeKeys
extends Control
## The Base console's four mode keys (interface-reference.md section 8, base_console_modes):
## BUILD, POWER, STAFF, SECURITY, 120 x 32 and 5 px apart, the current one lit. A press shows
## that sub-tab (the hidden [BaseSubTabs] still drives the modes).
## Bible: docs/content/interface-reference.md section 8

const LABELS: Dictionary[StringName, StringName] = {
	BaseSubTabs.BUILD: &"BASE_MODE_BUILD",
	BaseSubTabs.ENERGY: &"BASE_MODE_POWER",
	BaseSubTabs.STAFF: &"BASE_MODE_STAFF",
	BaseSubTabs.SECURITY: &"BASE_MODE_SECURITY",
}

var _tabs: BaseSubTabs = null
var _keys: Dictionary[StringName, RefKey] = {}


func _init() -> void:
	name = &"ModeKeys"
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y: float = 0.0
	for tab: StringName in LABELS:
		var key: RefKey = RefKey.new()
		key.name = String(LABELS[tab])
		key.label = LABELS[tab]
		key.label_size = 16
		key.position = Vector2(0, y)
		key.size = Vector2(120, 32)
		add_child(key)
		_keys[tab] = key
		y += 37.0


## Drives [param tabs].
func bind(tabs: BaseSubTabs) -> void:
	_tabs = tabs
	for tab: StringName in _keys:
		_keys[tab].pressed.connect(tabs.show_tab.bind(tab))
	refresh()


## The key of [param tab].
func get_key(tab: StringName) -> RefKey:
	return _keys[tab]


func _process(_delta: float) -> void:
	refresh()


## Lights the current mode's key.
func refresh() -> void:
	if _tabs == null:
		return
	for tab: StringName in _keys:
		_keys[tab].style = (
			RefPaint.KeyStyle.LIT if tab == _tabs.shown() else RefPaint.KeyStyle.STEEL
		)
