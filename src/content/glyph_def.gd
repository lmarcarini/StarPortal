class_name GlyphDef
extends DefBase
## One of the 36 glyphs on a Ring. Glyph i stands for anchor i of a domain's anchor field;
## its artwork is that star cluster's shape as seen from Earth's region of space.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#data-model

## Position on the Ring, 0..35; glyph i stands for anchor i.
@export var index: int
## Translation key of the program's nickname, e.g. &"GLYPH_HERON_NAME".
@export var name_key: StringName
## Translation key of the picture description, e.g. &"GLYPH_HERON_PICTURE".
@export var picture_key: StringName
## Star positions in a unit square (0..1), 3..9 stars.
@export var points: PackedVector2Array
## Pairs of indices into [member points], each pair drawn as one constellation line.
@export var lines: PackedInt32Array
