class_name RingView
extends Control
## The Ring as seen through the control room glass: a 3D camera on the Gate Room (RingSet,
## rendered at a third of the view's resolution through the feed shader) with the 36 glyph
## marks, eight seal lamps (SealRing) and the event horizon (EventHorizon) drawn over it in
## 2D, lined up with the Ring by an orthographic camera. The feed renders only while the view
## is visible, or while [member keep_live] is set (the top bar's thumbnail). The horizon
## mirrors the Ring: The horizon mirrors the Ring: DARK (idle), DIALING (seals
## lighting, set by the dialing sequence), OPEN (a wormhole: a shimmer, after a short opening
## burst on a fresh lock) and CLOSING (a short fade back to DARK once the wormhole closes, for
## any reason). While OPEN the portal is clickable and focusable: a left click, or accept (Enter,
## gamepad A) with it focused, emits [signal portal_pressed]. Draws only; never changes state.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## overview.md#locked-decisions (Presentation: hybrid), technical-architecture.md#state-machines,
## docs/content/interface-pass.md section 6

## The horizon state changed to [param state] (a [enum Horizon]).
signal horizon_changed(state: int)
## The player clicked the open portal, or pressed accept with it focused.
signal portal_pressed

## What the Ring's centre shows.
enum Horizon { DARK, DIALING, OPEN, CLOSING }

## Smallest size the control asks for, in pixels.
const MIN_SIZE: Vector2 = Vector2(72, 72)
## Band width as a share of the outer radius.
const BAND_RATIO: float = 0.24
## Real seconds the horizon takes to fade out after the wormhole closes.
const CLOSE_SECONDS: float = 0.5
## Real seconds of the opening burst, and its peak; softer and slower with reduced flashing.
const BURST_SECONDS: float = 0.6
const BURST_PEAK: float = 1.0
const SOFT_BURST_SECONDS: float = 1.2
const SOFT_BURST_PEAK: float = 0.3
const GUNMETAL: Color = Color(0.36, 0.39, 0.42)
const GUNMETAL_EDGE: Color = Color(0.2, 0.22, 0.24)
const MARK_COLOR: Color = Color(0.7, 0.72, 0.74)
const _MARGIN: float = 14.0
const _ARC_POINTS: int = 72
const _EDGE_WIDTH: float = 2.0
const _MARK_SHARE: float = 0.6
const _FOCUS_COLOR: Color = UiPalette.SELECT
## The 3D feed renders at the view's size divided by this.
const FEED_DOWNSCALE: float = 3.0
const _FEED_SHADER: String = "res://src/ui/camera/feed_shader.gdshader"

## Keeps the feed rendering while the view is hidden (the top bar's thumbnail).
var keep_live: bool = false:
	set(value):
		keep_live = value
		_update_live()
## The 3D Gate Room behind the overlay.
var ring_set := RingSet.new()

var _state: Horizon = Horizon.DARK
var _viewport := SubViewport.new()
var _picture := TextureRect.new()
var _burst_seconds: float = BURST_SECONDS
var _marks: Array[GlyphDef] = []

@onready var _horizon: EventHorizon = %EventHorizon
@onready var _seals: SealRing = %SealRing


func _ready() -> void:
	for index: int in GateAddress.GLYPH_COUNT:
		var id: StringName = StringName(GlyphIcon.GLYPH_ID_FORMAT % index)
		_marks.append(Registry.get_def(id) as GlyphDef)
	_build_feed()
	set_process(false)


func _init() -> void:
	_viewport.add_child(ring_set)
	add_child(_viewport)


func _build_feed() -> void:
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = UiPalette.GROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9aa39c")
	environment.ambient_light_energy = 0.25
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	_picture.texture = _viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.show_behind_parent = true
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load(_FEED_SHADER) as Shader
	_picture.material = material
	add_child(_picture)
	move_child(_picture, 0)
	ring_set.camera.make_current()
	ring_set.set_lit(_seals.lit)
	_fit_feed()
	_update_live()


## The live picture of the Ring, for the top bar's thumbnail.
func feed_texture() -> Texture2D:
	return _viewport.get_texture()


## True while the 3D feed renders.
func is_feed_live() -> bool:
	return _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED


func _fit_feed() -> void:
	var pixels := Vector2i((size / FEED_DOWNSCALE).max(Vector2.ONE * 8.0))
	_viewport.size = pixels
	ring_set.frame(outer_radius(size) / FEED_DOWNSCALE, float(pixels.y))


func _update_live() -> void:
	var live: bool = keep_live or is_visible_in_tree()
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	)


func _enter_tree() -> void:
	EventBus.wormhole_closed.connect(_on_wormhole_closed)


func _exit_tree() -> void:
	EventBus.wormhole_closed.disconnect(_on_wormhole_closed)


func _get_minimum_size() -> Vector2:
	return MIN_SIZE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			queue_redraw()
			if is_node_ready():
				_fit_feed()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
			queue_redraw()
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_node_ready():
				_update_live()
				if not is_visible_in_tree():
					_settle()


func _gui_input(event: InputEvent) -> void:
	if _state != Horizon.OPEN:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var is_click: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if is_click or event.is_action_pressed(&"ui_accept"):
		accept_event()
		portal_pressed.emit()


func _process(delta: float) -> void:
	advance(delta)


## Shows what a Ring in [param mode] (a GateState.RingMode) looks like, at once and without
## the opening burst: after a load, or when the view is set up.
func setup(mode: int) -> void:
	_light(GateAddress.SEAL_COUNT if mode == GateState.RingMode.LOCKED else 0)
	match mode:
		GateState.RingMode.DIALING:
			_set_state(Horizon.DIALING)
		GateState.RingMode.LOCKED:
			_open(false)
		_:
			_set_state(Horizon.DARK)


## A dial began: all seals unlit, the centre dark.
func begin_dialing() -> void:
	_light(0)
	_set_state(Horizon.DIALING)


## The dial ended: a lock opens the horizon with its burst; anything else goes dark.
func end_dialing(is_locked: bool) -> void:
	if is_locked:
		_open(true)
		return
	_light(0)
	_set_state(Horizon.DARK)


## Lights [param count] seals, 0 to 8.
func set_lit(count: int) -> void:
	_light(count)


## Lights [param count] seal lamps and the 3D chevrons with them.
func _light(count: int) -> void:
	_seals.lit = count
	ring_set.set_lit(count)


## Returns the seals lit.
func get_lit() -> int:
	return _seals.lit


## Returns the horizon state, a [enum Horizon].
func get_horizon_state() -> int:
	return _state


## Returns the event horizon layer.
func get_event_horizon() -> EventHorizon:
	return _horizon


## Adds [param delta] real seconds to the shimmer, the burst and the closing fade. Called every
## frame while open or closing; tests call it to skip real waiting.
func advance(delta: float) -> void:
	match _state:
		Horizon.OPEN:
			_horizon.phase += delta
			_horizon.burst = maxf(0.0, _horizon.burst - delta * _burst_peak() / _burst_seconds)
		Horizon.CLOSING:
			_horizon.burst = 0.0
			_horizon.level = maxf(0.0, _horizon.level - delta / CLOSE_SECONDS)
			ring_set.set_horizon(_horizon.level)
			if _horizon.level <= 0.0:
				_set_state(Horizon.DARK)


## Returns the outer radius of the band in a control of [param area] pixels.
static func outer_radius(area: Vector2) -> float:
	return maxf(0.0, minf(area.x, area.y) / 2.0 - _MARGIN)


## Returns the radius of the event horizon, inside the band, in a control of [param area].
static func horizon_radius(area: Vector2) -> float:
	return outer_radius(area) * (1.0 - BAND_RATIO)


func _open(is_new: bool) -> void:
	_light(GateAddress.SEAL_COUNT)
	var is_soft: bool = Settings.get_bool(&"accessibility", &"reduced_flashing")
	_burst_seconds = SOFT_BURST_SECONDS if is_soft else BURST_SECONDS
	_horizon.level = 1.0
	_horizon.burst = _burst_peak() if is_new else 0.0
	ring_set.set_horizon(1.0)
	_set_state(Horizon.OPEN)


func _burst_peak() -> float:
	return SOFT_BURST_PEAK if _burst_seconds == SOFT_BURST_SECONDS else BURST_PEAK


## Off screen there is nothing to watch: a closing fade ends at once.
func _settle() -> void:
	if _state == Horizon.CLOSING:
		_set_state(Horizon.DARK)


func _set_state(state: Horizon) -> void:
	if state == Horizon.DARK or state == Horizon.DIALING:
		_horizon.level = 0.0
		_horizon.burst = 0.0
		ring_set.set_horizon(0.0)
	if state == Horizon.DARK:
		_light(0)
	set_process(state == Horizon.OPEN or state == Horizon.CLOSING)
	_set_clickable(state == Horizon.OPEN)
	if state == _state:
		return
	_state = state
	horizon_changed.emit(state)


## Only the open portal takes clicks and focus; otherwise clicks pass through.
func _set_clickable(is_clickable: bool) -> void:
	focus_mode = Control.FOCUS_ALL if is_clickable else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if is_clickable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if is_clickable else Control.CURSOR_ARROW
	)
	if not is_clickable and has_focus():
		release_focus()
	queue_redraw()


func _on_wormhole_closed(_reason: StringName) -> void:
	if _state != Horizon.OPEN:
		return
	_set_state(Horizon.CLOSING)
	if not is_visible_in_tree():
		_settle()


func _draw() -> void:
	var outer: float = outer_radius(size)
	if outer <= 0.0:
		return
	var center: Vector2 = size / 2.0
	var band: float = outer * BAND_RATIO
	var side: float = minf(band, TAU * (outer - band / 2.0) / GateAddress.GLYPH_COUNT)
	for index: int in _marks.size():
		var angle: float = -PI / 2.0 + TAU * float(index) / float(_marks.size())
		var spot: Vector2 = center + Vector2.from_angle(angle) * (outer - band / 2.0)
		_draw_mark(_marks[index], spot, side * _MARK_SHARE)
	if has_focus():
		draw_arc(center, outer + _EDGE_WIDTH * 2.0, 0.0, TAU, _ARC_POINTS, _FOCUS_COLOR, 2.0)


## Draws [param glyph]'s constellation in a square of [param side] centred on [param spot].
func _draw_mark(glyph: GlyphDef, spot: Vector2, side: float) -> void:
	if glyph == null or side <= 0.0:
		return
	var area: Rect2 = Rect2(spot - Vector2(side, side) / 2.0, Vector2(side, side))
	var stars: PackedVector2Array = GlyphIcon.star_positions(glyph.points, area)
	for pair: int in range(0, glyph.lines.size() - 1, 2):
		var from: int = glyph.lines[pair]
		var to: int = glyph.lines[pair + 1]
		if from < stars.size() and to < stars.size():
			draw_line(stars[from], stars[to], Color(MARK_COLOR, 0.7), 1.0, true)
	for star: Vector2 in stars:
		draw_circle(star, 1.0, MARK_COLOR)
