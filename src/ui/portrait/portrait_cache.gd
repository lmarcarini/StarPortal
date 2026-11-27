class_name PortraitCache
extends RefCounted
## Portrait textures drawn once per staff member and kept: keyed by id, redrawn only when
## that id's appearance record changes (docs/content/portraits.md, "The appearance record").
## Bible: docs/content/portraits.md

## Most portraits kept; past this the cache is emptied and refilled as asked.
const LIMIT: int = 512

static var _textures: Dictionary[StringName, ImageTexture] = {}
static var _records: Dictionary[StringName, Dictionary] = {}


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
