class_name RoomCameraFeed
extends Control
## A security camera feed: a room set rendered at 320 × 240 in its own world, upscaled with
## the feed shader (scanlines, grain, slight bloom), with the camera's label over it. A feed
## that is not live does not render. "NO SIGNAL" shows when there is no set.
## Bible: docs/content/interface-pass.md sections 1 and 5 (Camera inset)

## The feed's resolution.
const RESOLUTION: Vector2i = Vector2i(320, 240)
const _SHADER: String = "res://src/ui/camera/feed_shader.gdshader"

## The low-resolution viewport the set renders into.
var viewport := SubViewport.new()
## The upscaled picture.
var picture := TextureRect.new()
## The camera's label, top-left.
var label := Label.new()
## "NO SIGNAL", over a dark picture.
var no_signal := Label.new()

var _set: RoomSet = null
var _live: bool = true
var _environment := WorldEnvironment.new()


func _init() -> void:
	custom_minimum_size = Vector2(RESOLUTION)
	clip_contents = true
	viewport.size = RESOLUTION
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0b0d0c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9aa39c")
	environment.ambient_light_energy = 0.6
	_environment.environment = environment
	viewport.add_child(_environment)
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(_SHADER) as Shader
	picture.material = material
	add_child(picture)
	_add_labels()
	show_no_signal()


func _add_labels() -> void:
	label.theme_type_variation = &"DataLabel"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.position = Vector2(8, 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	no_signal.text = &"CAMERA_NO_SIGNAL"
	no_signal.theme_type_variation = &"DataLabel"
	no_signal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_signal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_signal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	no_signal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(no_signal)


## Shows [param room_set] with [param text] as the camera's label ("CAM 03 RESEARCH LAB").
## The feed owns the set from then on and frees the one it showed before.
func show_set(room_set: RoomSet, text: String) -> void:
	_drop_set()
	_set = room_set
	viewport.add_child(room_set)
	room_set.camera.make_current()
	label.text = text
	no_signal.visible = false
	_apply_state()


## Starts or stops rendering. A feed that is not visible should be set not live.
func set_live(on: bool) -> void:
	_live = on
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	)


## True while the feed renders.
func is_live() -> bool:
	return _live


## Shows "NO SIGNAL" and drops the set.
func show_no_signal() -> void:
	_drop_set()
	label.text = ""
	no_signal.visible = true


## The set shown, or null.
func get_set() -> RoomSet:
	return _set


## Passes [param state] (on, off, site) to the set; an off room's feed goes dark.
func set_room_state(state: StringName) -> void:
	if _set == null:
		return
	_set.set_state(state)
	_apply_state()


func _apply_state() -> void:
	var dark: bool = _set != null and _set.get_state() == RoomSet.STATE_OFF
	_environment.environment.ambient_light_energy = 0.04 if dark else 0.6


func _drop_set() -> void:
	if _set == null:
		return
	viewport.remove_child(_set)
	_set.queue_free()
	_set = null
