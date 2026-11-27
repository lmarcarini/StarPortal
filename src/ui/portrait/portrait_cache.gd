class_name PortraitCache
extends RefCounted
## Portrait textures drawn once per staff member and kept: keyed by id, redrawn only when
## that id's appearance record changes (docs/content/portraits.md, "The appearance record").
## Full-body sprite sheets are kept the same way (sprite_frames_for()).
## Bible: docs/content/portraits.md

## Most portraits kept; past this the cache is emptied and refilled as asked.
const LIMIT: int = 512

static var _textures: Dictionary[StringName, ImageTexture] = {}
static var _records: Dictionary[StringName, Dictionary] = {}
static var _bodies: Dictionary[StringName, SpriteFrames] = {}
static var _body_records: Dictionary[StringName, Dictionary] = {}


## The portrait texture of [param id] for [param record], drawn on first ask.
static func texture_for(id: StringName, record: Dictionary) -> ImageTexture:
	if _textures.has(id) and _records[id] == record:
		return _textures[id]
	if _textures.size() >= LIMIT:
		clear()
	var texture: ImageTexture = ImageTexture.create_from_image(PortraitPainter.paint(record))
	_textures[id] = texture
	_records[id] = record.duplicate()
	return texture


## The full-body SpriteFrames of [param id] for [param record] (BodyPainter.sprite_frames():
## every BodyFrames animation, "walk_back" and so on), drawn on first ask.
static func sprite_frames_for(id: StringName, record: Dictionary) -> SpriteFrames:
	if _bodies.has(id) and _body_records[id] == record:
		return _bodies[id]
	if _bodies.size() >= LIMIT:
		clear()
	var frames: SpriteFrames = BodyPainter.sprite_frames(record)
	_bodies[id] = frames
	_body_records[id] = record.duplicate()
	return frames


## True when [param id] has a texture kept.
static func has(id: StringName) -> bool:
	return _textures.has(id)


## Number of textures kept.
static func size() -> int:
	return _textures.size()


## Forgets every texture.
static func clear() -> void:
	_textures.clear()
	_records.clear()
	_bodies.clear()
	_body_records.clear()
