class_name ShellLayout
extends RefCounted
## Where the shell puts the views under the frame (interface-reference.md sections 1, 2 and
## 4): the Gate station full bleed behind every bar and panel (its console drawn over the
## bottom bar); every other station's views in the station area, with their own folder strip
## inside it when the station has more than one folder, on the plain backdrop.
## Bible: docs/content/interface-reference.md sections 1, 2 and 4

## Z index of the Gate console over the frame's bottom bar.
const CONSOLE_Z: int = 1


## Lays out [param switcher], [param backdrop] and [param frame] for the current station.
static func fit(switcher: ViewSwitcher, backdrop: Control, frame: Frame) -> void:
	var gate: bool = switcher.current_station() == &"gate"
	backdrop.visible = not gate
	frame.show_station_console(not gate)
	var folders: Array = ViewSwitcher.STATIONS.get(switcher.current_station(), [])
	switcher.get_tab_bar().visible = folders.size() > 1
	switcher.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if gate:
		switcher.position = Vector2.ZERO
		switcher.size = frame.size
		_raise_console(switcher)
		return
	var area: Rect2 = FrameLayout.station_area(frame.size.x)
	switcher.position = area.position
	switcher.size = area.size


## What focus goes down to from the frame: the folder tabs, or the view when the station has
## no tab strip.
static func focus_below(switcher: ViewSwitcher) -> Control:
	var tabs: TabBar = switcher.get_tab_bar()
	if tabs.visible:
		return tabs
	var view: GameView = switcher.get_view(switcher.current_view_id())
	var focus: Control = null if view == null else view.get_default_focus()
	return tabs if focus == null else focus


## Puts the Gate console over the frame's bottom bar, right of the station keys (its own
## layout is the Gate station's: M4.11-03).
static func _raise_console(switcher: ViewSwitcher) -> void:
	var gate: GateStationView = switcher.get_view(ViewSwitcher.GATE_ROOM) as GateStationView
	if gate == null or not gate.is_node_ready():
		return
	var console: Control = gate.get_console()
	console.z_index = CONSOLE_Z
	console.offset_left = FrameLayout.REGIONS[&"station_console"].position.x
