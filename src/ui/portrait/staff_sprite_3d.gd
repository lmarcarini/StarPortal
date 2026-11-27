class_name StaffSprite3D
extends AnimatedSprite3D
## One staff member as a lit 2D-HD billboard in a 3D station (docs/content/portraits.md,
## "Full body"): the 64×128 full-body SpriteFrames from [PortraitCache], turned to the camera
## about Y only, shaded so the hall's lights (Ring glow, spotlights) reach it, alpha scissor
## (no sorting flicker), nearest filter, sized so a person stands about 1.8 m with the feet
## on the node's origin, and casting no shadow. Picks front, back or side (side mirrored
## with flip_h when walking left on screen) from the way it moves seen from the camera.
## The sheets cost about 185 ms each to draw, so they are built lazily: a sprite asks with
## [method show_person], waits in a queue, and at most one sheet is drawn per frame for all
## sprites together. The sprite stays hidden until its sheet is ready.
## Bible: docs/content/portraits.md; art-and-audio ("Characters")

## Metres per sprite pixel: a 112 px tall person (head to boots) stands about 1.8 m.
const PIXEL_SIZE: float = 1.8 / 112.0
## Pixels the sprite is lifted so the boots (BodyPainter.BASELINE) sit on the origin.
const FEET_OFFSET: float = BodyPainter.H * 0.5 - (BodyPainter.BASELINE + 1)
## Below this share of the screen-space motion the person faces front or back, not side.
const SIDE_SHARE: float = 0.6

## Sprites waiting for their sheet, oldest first.
static var _queue: Array[StaffSprite3D] = []
## The process frame the last sheet was drawn on.
static var _built_frame: int = -1

## The staff id shown, or &"".
var person_id: StringName = &""
var _record: Dictionary = {}
var _pose: String = "idle"
var _direction: String = "front"
var _wanted: bool = true


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	shaded = true
	double_sided = true
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.5
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pixel_size = PIXEL_SIZE
	offset = Vector2(0.0, -FEET_OFFSET)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _exit_tree() -> void:
	_queue.erase(self)


## Shows [param id] drawn from [param record]; the sheet is built on a later frame unless
## the cache has it. An empty record hides the sprite.
func show_person(id: StringName, record: Dictionary) -> void:
	if id == person_id and record == _record and sprite_frames != null:
		return
	person_id = id
	_record = record.duplicate()
	sprite_frames = null
	visible = false
	if record.is_empty():
		_queue.erase(self)
		return
	if not _queue.has(self):
		_queue.append(self)


## True once the sheet is built and shown.
func is_ready() -> bool:
	return sprite_frames != null


## Shows or hides the sprite; it shows only once its sheet is ready.
func set_wanted(wanted: bool) -> void:
	_wanted = wanted
	visible = wanted and is_ready()


## Plays [param pose] ("idle", "walk", "work") facing [param direction] ("front", "back",
## "side"), mirrored when [param left].
func set_pose(pose: String, direction: String, left: bool = false) -> void:
	_pose = pose
	_direction = direction
	flip_h = left and direction == "side"
	_apply()


## Faces the way of world motion [param motion] as seen from [param camera], walking (or
## [param pose]).
func face_motion(motion: Vector3, camera: Camera3D, pose: String = "walk") -> void:
	if camera == null or motion.length_squared() < 0.000001:
		set_pose(pose, _direction, flip_h)
		return
	var view: Dictionary = StaffSprite3D.direction_of(motion, camera.global_transform.basis)
	var direction: String = view["direction"]
	var left: bool = view["left"]
	set_pose(pose, direction, left)


## The direction a person moving by [param motion] shows to a camera with [param basis]:
## {"direction": "front"|"back"|"side", "left": bool}.
static func direction_of(motion: Vector3, basis: Basis) -> Dictionary:
	var right: float = motion.dot(basis.x)
	var toward: float = motion.dot(basis.z)
	var flat: float = Vector2(right, toward).length()
	if flat > 0.0 and absf(right) / flat >= SIDE_SHARE:
		return {"direction": "side", "left": right < 0.0}
	return {"direction": "front" if toward > 0.0 else "back", "left": false}


## Sheets waiting to be built.
static func pending() -> int:
	return _queue.size()


## Builds the next waiting sheet now, ignoring the one-per-frame limit (tests, captures).
static func build_next() -> void:
	if _queue.is_empty():
		return
	var sprite: StaffSprite3D = _queue.pop_front()
	sprite._build()


func _process(_delta: float) -> void:
	if _queue.is_empty() or _queue[0] != self:
		return
	var now: int = Engine.get_process_frames()
	if now == _built_frame:
		return
	_built_frame = now
	_queue.pop_front()
	_build()


func _build() -> void:
	sprite_frames = PortraitCache.sprite_frames_for(person_id, _record)
	_apply()
	visible = _wanted


func _apply() -> void:
	if sprite_frames == null:
		return
	var anim := StringName(BodyFrames.animation(_pose, _direction))
	if not sprite_frames.has_animation(anim):
		return
	if animation != anim:
		var at: int = frame
		animation = anim
		frame = at % sprite_frames.get_frame_count(anim)
	if not is_playing():
		play()
