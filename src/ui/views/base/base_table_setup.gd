class_name BaseTableSetup
extends RefCounted
## Sets the Base view up as the lit plan table (M6-02): adds the table furniture behind the
## controls and the console's mode keys, hides what the reference does not show (the room
## camera, the old staff list, the power switch: the room card's POWER key drives it), and
## lays every part on its region.
## Bible: docs/content/interface-reference.md section 8


## Sets [param view] up with [param card] and [param modes].
static func ready(view: BaseView, card: RoomCard, modes: BaseModeKeys) -> void:
	var table: BaseTable = BaseTable.new()
	view.add_child(table)
	view.move_child(table, 0)
	view.add_child(modes)
	modes.bind(view.get_sub_tabs())
	view.room_camera.visible = false
	view.get_staff_slots().visible = false
	view.get_plan().tray.enabled = false
	view.get_plan().tray.visible = false
	view.get_plan().staff_layer.visible = false
	card.power_pressed.connect(view.get_power().room_switch.toggle_requested.emit)
	view.resized.connect(place.bind(view, card, modes))
	place(view, card, modes)


## Puts every part of [param view] on its region.
static func place(view: BaseView, card: RoomCard, modes: BaseModeKeys) -> void:
	var regions: Dictionary[Control, StringName] = {
		view.get_node(^"%LevelTabs") as Control: &"base_levels",
		view.get_node(^"%Glass") as Control: &"base_glass",
		view.get_node(^"%Tray") as Control: &"base_console_tray",
		modes: &"base_console_modes",
		card: &"room_panel",
	}
	for control: Control in regions:
		BaseLayout.place(control, regions[control], view.size.x)
	var levels: Control = view.get_node(^"%LevelTabs") as Control
	levels.size.y = LevelTabs.DIG_TOP + LevelTabs.DIG_SIZE.y + 30.0


## "$2.5M" or "$600k" for [param amount_k] thousand dollars.
static func short_money(amount_k: int) -> String:
	if absi(amount_k) >= 1000:
		return "$%sM" % String.num(amount_k / 1000.0, 1).trim_suffix(".0")
	return "$%dk" % amount_k
