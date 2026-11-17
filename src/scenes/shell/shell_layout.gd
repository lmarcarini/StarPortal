class_name ShellLayout
extends RefCounted
## Where the shell puts the views under the frame (interface-reference.md sections 1, 2 and
## 4): the Gate station full bleed behind every bar and panel (its console drawn over the
## bottom bar); every other station's views in the station area, with their own folder strip
## inside it when the station has more than one folder, on the plain backdrop.
## Bible: docs/content/interface-reference.md sections 1, 2 and 4

## Z index of everything the shell puts over the frame (pause menu, conversations, the
## game over and after-action screens, alerts, toasts): above the station and the frame,
## whose own layers stay below 100.
const OVERLAY_Z: int = 200


## Raises every child of [param shell] after [param frame] to [constant OVERLAY_Z].
static func raise_overlays(shell: Node, frame: Frame) -> void:
	for child: Node in shell.get_children():
		var item: CanvasItem = child as CanvasItem
		if item != null and child.get_index() > frame.get_index():
			item.z_index = maxi(item.z_index, OVERLAY_Z)


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
