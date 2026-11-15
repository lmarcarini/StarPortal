class_name PortraitWindow
extends PanelContainer
## The small screen inside the dialogue screen that shows whoever is talking
## (docs/content/dialogue-screen.md section 3): the portrait, drawn by the renderer of its
## PortraitDef kind, seen through the same video look on every channel (scanlines, grain, a
## slow roll), in a frame whose accent and label depend on the channel. A still shows a fixed
## picture and reads STILL instead of LIVE. With reduced motion (display/ambient_movement off)
## only the mouth moves. Presentation only.
## Bible: docs/content/dialogue-screen.md section 3

## Pixels of the frame at UI scale 1.
const FRAME_WIDTH: int = 3
## The video is drawn at 1 / this resolution, then upscaled.
const VIDEO_SHRINK: int = 2
const _SHADER: Shader = preload("res://src/ui/camera/feed_shader.gdshader")

## Every PortraitDef by id (the screen sets it from the state).
var portrait_defs: Dictionary[StringName, PortraitDef] = {}

var _frame := StyleBoxFlat.new()
var _video := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _channel_label := Label.new()
var _state_label := Label.new()
var _renderer: PortraitRenderer = null
var _speaker: StringName = &""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.bg_color = Color.BLACK
	_frame.set_border_width_all(FRAME_WIDTH)
	add_theme_stylebox_override(&"panel", _frame)
	var layers := Control.new()
	layers.clip_contents = true
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layers)
	_video.stretch = true
	_video.stretch_shrink = VIDEO_SHRINK
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var look := ShaderMaterial.new()
	look.shader = _SHADER
	look.set_shader_parameter(&"roll", 1.0)
	look.set_shader_parameter(&"lines", 160.0)
	_video.material = look
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_video.add_child(_viewport)
	layers.add_child(_video)
	_add_label(layers, _channel_label, Control.PRESET_TOP_LEFT)
	_add_label(layers, _state_label, Control.PRESET_TOP_RIGHT)
	set_channel(&"wormhole", "")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_on_screen()


func _enter_tree() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	_sync_on_screen.call_deferred()


func _exit_tree() -> void:
	Settings.setting_changed.disconnect(_on_setting_changed)


## Shows [param speaker] in [param mood]; a new speaker swaps the portrait, the same one only
## changes the mood. A speaker without a known portrait leaves the window empty.
func show_speaker(speaker: SpeakerDef, mood: StringName) -> void:
	if speaker == null:
		return
	if speaker.id != _speaker or _renderer == null:
		_swap(speaker)
	if _renderer != null:
		_renderer.set_mood(mood)


## The mouth moves while [param on] (follows the transcript's typing).
func set_talking(on: bool) -> void:
	if _renderer != null:
		_renderer.set_talking(on)


## Sets the frame accent and label for [param channel] at [param world_name].
func set_channel(channel: StringName, world_name: String) -> void:
	_frame.border_color = ChannelStyle.accent(channel)
	_channel_label.text = ChannelStyle.label(channel, world_name)
	_channel_label.add_theme_color_override(&"font_color", ChannelStyle.accent(channel))


## Removes the portrait (the screen closed).
func clear() -> void:
	if _renderer != null:
		_viewport.remove_child(_renderer)
		_renderer.free()
	_renderer = null
	_speaker = &""
	_state_label.text = ""


## The renderer drawing now, or null.
func get_renderer() -> PortraitRenderer:
	return _renderer


## The channel label and the LIVE/STILL label.
func get_label_texts() -> Array[String]:
	return [_channel_label.text, _state_label.text]


## The frame's accent.
func get_frame_colour() -> Color:
	return _frame.border_color


## The viewport the portrait is drawn in (the video look is applied to it).
func get_video() -> SubViewportContainer:
	return _video


func _swap(speaker: SpeakerDef) -> void:
	clear()
	_speaker = speaker.id
	var portrait: PortraitDef = portrait_defs.get(speaker.portrait)
	_renderer = PortraitRenderer.create(portrait)
	if _renderer == null:
		return
	_viewport.add_child(_renderer)
	_renderer.set_animated(Settings.get_bool(&"display", &"ambient_movement"))
	_sync_on_screen()
	_state_label.text = ChannelStyle.state_label(portrait.still)
	var live: Color = UiPalette.TEXT_DIM if portrait.still else UiPalette.ALARM
	_state_label.add_theme_color_override(&"font_color", live)


## The portrait animates and the video renders only while the window is visible.
func _sync_on_screen() -> void:
	var shown: bool = is_inside_tree() and is_visible_in_tree()
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_WHEN_VISIBLE if shown else SubViewport.UPDATE_DISABLED
	)
	if _renderer != null:
		_renderer.set_on_screen(shown)


func _add_label(parent: Control, label: Label, preset: Control.LayoutPreset) -> void:
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override(&"font_size", 13)
	var font: Font = UiThemeBuilder.label_font()
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 8)
	if preset == Control.PRESET_TOP_RIGHT:
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"display" and key == &"ambient_movement" and _renderer != null:
		_renderer.set_animated(Settings.get_bool(&"display", &"ambient_movement"))
