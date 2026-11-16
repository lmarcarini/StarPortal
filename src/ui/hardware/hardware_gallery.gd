extends Control
## Review gallery: every hardware control in every state, on a steel plate, for the owner and
## for screenshots. Not part of the game flow.
## Bible: docs/content/interface-rethink.md section 7


func _ready() -> void:
	theme = UiThemeBuilder.build(1.0)
	var plate: SteelPanel = SteelPanel.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 16)
	plate.add_child(rows)
	rows.add_child(_keys_row())
	rows.add_child(_icons_row())
	rows.add_child(_states_row())
	rows.add_child(_gauges_row())


func _row(parent_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = parent_name
	row.add_theme_constant_override(&"separation", 12)
	return row


func _keys_row() -> HBoxContainer:
	var row: HBoxContainer = _row("Keys")
	for style: BigKey.KeyStyle in [
		BigKey.KeyStyle.AMBER, BigKey.KeyStyle.HAZARD, BigKey.KeyStyle.RED
	]:
		var key: BigKey = BigKey.new()
		key.key_style = style
		key.text = "HW_KEY_DIAL"
		key.hold_to_confirm = style == BigKey.KeyStyle.HAZARD
		row.add_child(key)
	var off: BigKey = BigKey.new()
	off.text = "HW_KEY_GO"
	off.disabled = true
	row.add_child(off)
	for down: bool in [false, true]:
		var lever: Lever = Lever.new()
		lever.button_pressed = down
		row.add_child(lever)
	return row


func _icons_row() -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "Icons"
	for id: StringName in HardwareIcons.IDS:
		var key: IconKey = IconKey.new()
		key.icon_id = id
		key.set_help("HW_ICON_" + String(id).to_upper())
		row.add_child(key)
	return row


func _states_row() -> HBoxContainer:
	var row: HBoxContainer = _row("States")
	for state: IconKey.KeyState in [0, 1, 2, 3]:
		var key: IconKey = IconKey.new()
		key.icon_id = &"team"
		key.badge_text = "3"
		row.add_child(key)
		key.set_state(state)
	for on: bool in [false, true]:
		var lamp: IndicatorLamp = IndicatorLamp.new()
		lamp.custom_minimum_size = Vector2(44, 44)
		lamp.set_lit(on)
		row.add_child(lamp)
	var crt: CrtMonitor = CrtMonitor.new()
	var label: Label = Label.new()
	label.text = "P3X-774"
	crt.add_child(label)
	row.add_child(crt)
	var card: PaperCard = PaperCard.new()
	var ink: Label = Label.new()
	ink.text = "HW_ICON_SURVEYED"
	card.add_child(ink)
	row.add_child(card)
	return row


func _gauges_row() -> HBoxContainer:
	var row: HBoxContainer = _row("Gauges")
	for v: float in [10.0, 55.0, 95.0]:
		var gauge: AnalogGauge = AnalogGauge.new()
		gauge.red_from = 80.0
		gauge.need_mark = 40.0
		gauge.set_value(v, "%d" % v)
		row.add_child(gauge)
	return row
