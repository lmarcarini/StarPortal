class_name PlateSpace
extends RefCounted
## Pure maths between plate pixels and screen pixels. The plate covers the station rect: scaled
## evenly to fill it and cropped evenly on the long side, never letterboxed, never stretched.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)


## Uniform scale that makes a plate of [param plate_size] cover [param rect].
static func cover_scale(plate_size: Vector2, rect: Rect2) -> float:
	if plate_size.x <= 0.0 or plate_size.y <= 0.0:
		return 1.0
	return maxf(rect.size.x / plate_size.x, rect.size.y / plate_size.y)


## Screen position of the plate's top-left corner when it covers [param rect].
static func origin(plate_size: Vector2, rect: Rect2) -> Vector2:
	var s: float = cover_scale(plate_size, rect)
	return rect.position + (rect.size - plate_size * s) * 0.5


## Screen pixel of plate pixel [param p] for [param def] covering [param rect].
static func to_screen(def: StationSceneDef, rect: Rect2, p: Vector2) -> Vector2:
	var size: Vector2 = Vector2(def.plate_size)
	return origin(size, rect) + p * cover_scale(size, rect)


## Plate pixel of screen pixel [param p] for [param def] covering [param rect].
static func to_plate(def: StationSceneDef, rect: Rect2, p: Vector2) -> Vector2:
	var size: Vector2 = Vector2(def.plate_size)
	return (p - origin(size, rect)) / cover_scale(size, rect)


## Screen length of plate length [param length].
static func to_screen_length(def: StationSceneDef, rect: Rect2, length: float) -> float:
	return length * cover_scale(Vector2(def.plate_size), rect)


## Every point of [param points] mapped to the screen.
static func to_screen_all(
	def: StationSceneDef, rect: Rect2, points: PackedVector2Array
) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		out.append(to_screen(def, rect, p))
	return out
