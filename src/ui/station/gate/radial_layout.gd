class_name RadialLayout
extends RefCounted
## Where each of the 36 glyph keys sits on the alien panel: three rings of twelve round a
## centre key, glyph i on ring i / 12 at slot i % 12, slot 0 at the top, clockwise. The place
## of a glyph never changes. Also maps a stick direction to a key. Pure.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## Keys per ring.
const PER_RING: int = 12
## Rings.
const RINGS: int = 3
## Ring radii as a share of the panel's radius, inner to outer.
const RADII: Array[float] = [0.4, 0.67, 0.94]
## Largest key side as a share of the panel radius (the inner ring's neighbour spacing is
## about 0.21 of it).
const SIDE_SHARE: float = 0.19
## Stick length below which it points at nothing.
const DEADZONE: float = 0.3


## Ring of glyph [param glyph], 0 inner to 2 outer.
static func ring_of(glyph: int) -> int:
	return glyph / PER_RING


## Slot of glyph [param glyph] on its ring, 0 at the top, clockwise.
static func slot_of(glyph: int) -> int:
	return glyph % PER_RING


## Angle in radians of slot [param slot] (0 is straight up, growing clockwise on screen).
static func angle_of(slot: int, ring: int) -> float:
	var stagger: float = 0.5 if ring == 1 else 0.0
	return -PI / 2.0 + TAU * (float(slot) + stagger) / PER_RING


## Centre of glyph [param glyph]'s key, for a panel centred at [param centre] of radius
## [param radius].
static func position_of(glyph: int, centre: Vector2, radius: float) -> Vector2:
	var ring: int = ring_of(glyph)
	return centre + Vector2.from_angle(angle_of(slot_of(glyph), ring)) * radius * RADII[ring]


## The glyph a stick at [param stick] points at, or -1 inside the deadzone. The direction
## picks the slot; the length picks the ring (short inner, long outer).
static func glyph_at_stick(stick: Vector2) -> int:
	var length: float = stick.length()
	if length < DEADZONE:
		return -1
	var ring: int = 0
	if length > 0.92:
		ring = 2
	elif length > 0.62:
		ring = 1
	var stagger: float = 0.5 if ring == 1 else 0.0
	var turns: float = fposmod(stick.angle() + PI / 2.0, TAU) / TAU * PER_RING - stagger
	var slot: int = posmod(roundi(turns), PER_RING)
	return ring * PER_RING + slot


## Panel radius whose outer ring of keys [param key_size] wide fits inside [param area].
static func radius_for(area: Vector2, key_size: float) -> float:
	var half: float = minf(area.x, area.y) * 0.5 - key_size * 0.5
	return maxf(0.0, half / RADII[RINGS - 1])


## Side of a glyph key on a panel of [param radius]: [param base], shrunk so neighbours on the
## inner ring and keys on the next ring never touch.
static func key_side(radius: float, base: float) -> float:
	return minf(base, radius * SIDE_SHARE)
