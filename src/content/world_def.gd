class_name WorldDef
extends DefBase
## An authored Ring-bearing world (CAIRN now; story worlds later), placed in the same space as
## the anchors so its address follows from its position.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy, technical-architecture.md#data-model

## State of a world's Ring as the dialing side sees it. BURIED and SHIELDED Rings answer a
## dial with Blocked.
enum RingStatus { OPEN, BURIED, SHIELDED }

## Translation key of the world's name.
@export var name_key: StringName
## Position in light years, in the same space as the anchors.
@export var position_ly: Vector3i
## This world's Ring's origin glyph, 0..35.
@export var origin_glyph: int
## State of this world's Ring.
@export var ring_status: RingStatus = RingStatus.OPEN
## True when the far side is guarded: a lock here is a Hostile lock.
@export var is_guarded: bool = false
## True only for CAIRN, the player's home Ring.
@export var is_home: bool = false
