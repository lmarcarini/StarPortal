class_name PortraitRenderer
extends Control
## Base of the renderers that draw a speaker inside the portrait window, one per PortraitDef
## kind. The window only calls setup(), set_mood(), set_talking() and set_animated(); a new
## kind is one renderer class and one line in [constant KINDS] (or register_kind() in a test).
## Animation uses the renderer's own random stream and runs only while it is visible.
## Bible: docs/content/dialogue-screen.md section 3

## The renderer script of each PortraitDef kind.
const KINDS: Dictionary[StringName, String] = {
	&"placeholder": "res://src/ui/dialog/placeholder_portrait.gd",
}

static var _extra_kinds: Dictionary[StringName, Script] = {}

## The definition drawn.
var def: PortraitDef = null
## The mood shown (&"neutral" when none).
var mood: StringName = &"neutral"
## True while the speaker talks (the mouth moves).
var talking: bool = false
## Idle movement (breathing, blinking) on; off for a still or with reduced motion.
var animated: bool = true
## The renderer's own random stream.
var rng := RandomNumberGenerator.new()
## False while the window showing it is hidden (it lives in a SubViewport, so its own
## visibility does not follow the screen's).
var on_screen: bool = true


## A renderer for [param portrait] by its kind, set up; null for an unknown kind.
static func create(portrait: PortraitDef) -> PortraitRenderer:
	if portrait == null:
		return null
	var script: Script = _extra_kinds.get(portrait.kind)
	if script == null and KINDS.has(portrait.kind):
		script = load(KINDS[portrait.kind])
	if script == null:
		return null
	var made: Object = (script as GDScript).new()
	var renderer: PortraitRenderer = made as PortraitRenderer
	renderer.setup(portrait)
	return renderer


## Adds or replaces the renderer of [param kind] (tests); a null [param script] removes it.
static func register_kind(kind: StringName, script: Script) -> void:
	if script == null:
		_extra_kinds.erase(kind)
	else:
		_extra_kinds[kind] = script


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_refresh_process()


## Draws [param portrait]; seeds the random stream from its id so a speaker always moves alike.
func setup(portrait: PortraitDef) -> void:
	def = portrait
	rng.seed = hash(portrait.id)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


## Shows [param new_mood] (empty means neutral).
func set_mood(new_mood: StringName) -> void:
	mood = &"neutral" if new_mood.is_empty() else new_mood
	queue_redraw()


## Starts or stops the mouth (a still never talks).
func set_talking(on: bool) -> void:
	talking = on and not def.still
	_refresh_process()
	queue_redraw()


## Turns idle movement on or off (always off for a still).
func set_animated(on: bool) -> void:
	animated = on and not def.still
	_refresh_process()
	queue_redraw()


## Stops all animation while [param shown] is false (the window is hidden).
func set_on_screen(shown: bool) -> void:
	on_screen = shown
	_refresh_process()


## True when the renderer needs _process: idle movement or a moving mouth.
func wants_process() -> bool:
	return animated or talking


func _refresh_process() -> void:
	set_process(on_screen and is_inside_tree() and is_visible_in_tree() and wants_process())
