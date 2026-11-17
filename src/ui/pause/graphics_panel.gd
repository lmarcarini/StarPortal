class_name GraphicsPanel
extends VBoxContainer
## The pause menu's GRAPHICS section: 3D stations on or off, quality LOW or MEDIUM (a two-way
## switch: the current side amber), screen grain and reduced motion, as reference keys (a lit
## key is on). Each press writes the setting, which saves at once and applies live through
## Settings.setting_changed. Keyboard, mouse and gamepad (they are Buttons).
## Bible: docs/content/interface-reference.md section 3

## Toggle keys: setting key, label key; reduced motion is the inverse of ambient_movement.
const TOGGLES: Dictionary[StringName, StringName] = {
	&"stations_3d": &"GRAPHICS_3D",
	&"screen_grain": &"GRAPHICS_GRAIN",
	&"ambient_movement": &"GRAPHICS_REDUCED_MOTION",
}
## Key size, in pixels.
const KEY: Vector2 = Vector2(168, 56)

var _toggles: Dictionary[StringName, RefKey] = {}
var _low: RefKey = RefKey.new()
var _medium: RefKey = RefKey.new()


func _init() -> void:
	name = &"GraphicsPanel"
	add_theme_constant_override(&"separation", 8)
	var title: Label = Label.new()
	title.text = &"GRAPHICS_TITLE"
	title.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL, 0, RefPaint.TEXT, 2.0).get_font()
	)
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", RefPaint.DIM)
	add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	add_child(grid)
	for key: StringName in TOGGLES:
		_toggles[key] = _key(grid, TOGGLES[key])
		_toggles[key].pressed.connect(toggle.bind(key))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	var quality: Label = Label.new()
	quality.text = &"GRAPHICS_QUALITY"
	quality.custom_minimum_size.x = KEY.x
	quality.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quality.add_theme_font_override(&"font", title.get_theme_font(&"font"))
	quality.add_theme_font_size_override(&"font_size", 20)
	quality.add_theme_color_override(&"font_color", RefPaint.TEXT)
	row.add_child(quality)
	_key_into(row, _low, &"GRAPHICS_LOW")
	_low.pressed.connect(set_quality.bind("low"))
	_key_into(row, _medium, &"GRAPHICS_MEDIUM")
	_medium.pressed.connect(set_quality.bind("medium"))
	refresh()


func _enter_tree() -> void:
	Settings.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	Settings.setting_changed.disconnect(_on_setting_changed)


## Flips setting [param key] (reduced motion flips ambient_movement).
func toggle(key: StringName) -> void:
	Settings.set_value(&"display", key, not Settings.get_bool(&"display", key))


## Sets the quality to [param quality] ("low" or "medium").
func set_quality(quality: String) -> void:
	Settings.set_value(&"display", &"quality", quality)


## Whether the key of [param key] shows on (reduced motion: ambient movement off).
func is_on(key: StringName) -> bool:
	return _toggles[key].style == RefPaint.KeyStyle.LIT


## The keys in focus order.
func get_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for key: StringName in TOGGLES:
		out.append(_toggles[key])
	out.append_array([_low, _medium])
	return out


## Shows the settings as they are.
func refresh() -> void:
	for key: StringName in TOGGLES:
		var on: bool = Settings.get_bool(&"display", key)
		if key == &"ambient_movement":
			on = not on
		_toggles[key].style = RefPaint.KeyStyle.LIT if on else RefPaint.KeyStyle.STEEL
	var low: bool = str(Settings.get_value(&"display", &"quality")) == "low"
	_low.style = RefPaint.KeyStyle.AMBER if low else RefPaint.KeyStyle.STEEL
	_medium.style = RefPaint.KeyStyle.STEEL if low else RefPaint.KeyStyle.AMBER


func _key(grid: GridContainer, label: StringName) -> RefKey:
	var key: RefKey = RefKey.new()
	_key_into(grid, key, label)
	return key


func _key_into(grid: Container, key: RefKey, label: StringName) -> void:
	key.name = String(label).capitalize().replace(" ", "")
	key.label = label
	key.label_size = 18
	key.custom_minimum_size = KEY
	grid.add_child(key)


func _on_setting_changed(section: StringName, _key_name: StringName, _value: Variant) -> void:
	if section == &"display":
		refresh()
