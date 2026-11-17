class_name StationSceneDef
extends DefBase
## One station: a plate (a picture of the empty room) and the anchors that tie live layers to
## it, all in plate pixels, so the picture can be swapped without touching code. With a
## [member scene] the station is a real-time 3D scene seen from a fixed camera instead
## (M5-01); its anchors then come from projecting the scene's named Marker3D and Path3D
## nodes, and the plate anchors stay the fallback for any it lacks.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)

## Anchors each live layer needs, by layer id. A def that lists a layer in [member layers]
## must carry every anchor named here (in points, circles, paths, polygons or rects).
const LAYER_ANCHORS: Dictionary[StringName, Array] = {
	&"ring": [&"ring_inner", &"ring_outer"],
	&"clamps":
	[
		&"clamp_0",
		&"clamp_1",
		&"clamp_2",
		&"clamp_3",
		&"clamp_4",
		&"clamp_5",
		&"clamp_6",
		&"clamp_7"
	],
	&"floor_glow": [&"floor_glow"],
	&"floor_actors": [&"ramp", &"door_left"],
	&"consoles": [&"console_left", &"console_right"],
	&"glyph_keys": [&"key_ring"],
	&"send_rail": [&"rail"],
}

## The plate picture; null shows a code-drawn placeholder of [member plate_size].
@export var plate: Texture2D
## Plate size in pixels; anchors are in this space.
@export var plate_size: Vector2i = Vector2i(1672, 941)
## Named points.
@export var points: Dictionary[StringName, Vector2] = {}
## Named circles: x, y and radius.
@export var circles: Dictionary[StringName, Vector3] = {}
## Named paths, first point to last.
@export var paths: Dictionary[StringName, PackedVector2Array] = {}
## Named polygons.
@export var polygons: Dictionary[StringName, PackedVector2Array] = {}
## Named rectangles.
@export var rects: Dictionary[StringName, Rect2] = {}
## Drawing scale at a path's first and last point (x = first, y = last).
@export var depth_scale: Dictionary[StringName, Vector2] = {}
## Live layers this station hosts; each needs its anchors from [constant LAYER_ANCHORS].
@export var layers: Array[StringName] = []
## The 3D scene (a Node3D holding the room, its lights and named markers); null keeps the
## plate.
@export var scene: PackedScene
## The fixed camera: its position, the point it looks at, and its vertical field of view in
## degrees.
@export var camera_position: Vector3 = Vector3(0, 1.7, 12)
@export var camera_target: Vector3 = Vector3(0, 3, 0)
@export var camera_fov: float = 50.0


## Returns true when an anchor called [param anchor_name] exists in any table.
func has_anchor(anchor_name: StringName) -> bool:
	return (
		points.has(anchor_name)
		or circles.has(anchor_name)
		or paths.has(anchor_name)
		or polygons.has(anchor_name)
		or rects.has(anchor_name)
	)


## Returns the anchors a listed layer needs that this def lacks, as "layer: anchor" lines.
func missing_anchors() -> Array[String]:
	var missing: Array[String] = []
	for layer: StringName in layers:
		if not LAYER_ANCHORS.has(layer):
			missing.append("unknown layer %s" % layer)
			continue
		for anchor_name: StringName in LAYER_ANCHORS[layer]:
			if not has_anchor(anchor_name):
				missing.append("%s: %s" % [layer, anchor_name])
	return missing


func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if plate_size.x <= 0 or plate_size.y <= 0:
		errors.append("has an empty plate size")
	if camera_fov <= 1.0 or camera_fov >= 170.0:
		errors.append("has a camera field of view out of range")
	for line: String in missing_anchors():
		errors.append("lacks anchor " + line)
	return errors
