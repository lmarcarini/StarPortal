extends SceneTree
## Writes the home domain's generated content from a fixed seed: the 36 anchor positions
## (`data/gate/home_anchor_field.tres`) and CAIRN (`data/gate/worlds/cairn.tres`). It never
## touches the hand-drawn glyph files in `data/gate/glyphs/`.
##
## Run from the project root:
## `godot --headless --path . --script tools/gen_home_domain.gd`
## The output is byte-for-byte the same on every run, so re-running it and checking
## `git diff --exit-code` proves the committed files are the tool's output.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

## Fixed seed: change it and every anchor, CAIRN and its origin glyph change.
const SEED: int = 5_150_036
## The slab, in light years: 30,000 x 30,000 x 3,000, centred on the origin.
const HALF_EXTENT_LY: Vector3i = Vector3i(15_000, 15_000, 1_500)
## Anchors are at least this far apart, in light years.
const MIN_ANCHOR_SPACING_LY: int = 2_500
## CAIRN is placed within this distance of the centre, inside the 3,000 ly the rule allows.
const CAIRN_MAX_RADIUS_LY: int = 2_400
## CAIRN keeps at least this distance from every anchor, so no glyph sits on top of the base.
const CAIRN_MIN_ANCHOR_GAP_LY: int = 600
## Number of nearest anchors the origin glyph must not be among (the address's seven coordinates).
const NEAREST_EXCLUDED: int = 7
## Rejection-sampling attempts before giving up on a placement.
const MAX_ATTEMPTS: int = 100_000

const ANCHOR_FIELD_PATH: String = "res://data/gate/home_anchor_field.tres"
const CAIRN_PATH: String = "res://data/gate/worlds/cairn.tres"


func _init() -> void:
	var files: Dictionary[String, String] = generated_files()
	var failed: bool = files.is_empty()
	for path: String in files:
		failed = failed or not _write(path, files[path])
	quit(1 if failed else 0)


## Returns the text of every generated file, keyed by its `res://` path; empty on failure.
static func generated_files() -> Dictionary[String, String]:
	var files: Dictionary[String, String] = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var anchors: Array[Vector3i] = place_anchors(rng)
	if anchors.size() != GateAddress.GLYPH_COUNT:
		push_error("gen_home_domain: could not place %d anchors" % GateAddress.GLYPH_COUNT)
		return files
	var position: Vector3i = place_cairn(rng, anchors)
	var origin: int = pick_origin_glyph(rng, position, anchors)
	files[ANCHOR_FIELD_PATH] = anchor_field_text(anchors)
	files[CAIRN_PATH] = cairn_text(position, origin)
	return files


## Places 36 anchors inside the slab, at least MIN_ANCHOR_SPACING_LY apart, by rejection
## sampling. Returns fewer when MAX_ATTEMPTS is exhausted.
static func place_anchors(rng: RandomNumberGenerator) -> Array[Vector3i]:
	var anchors: Array[Vector3i] = []
	var attempts: int = 0
	while anchors.size() < GateAddress.GLYPH_COUNT and attempts < MAX_ATTEMPTS:
		attempts += 1
		var candidate: Vector3i = _random_in_box(rng, HALF_EXTENT_LY)
		if _is_clear_of(candidate, anchors, MIN_ANCHOR_SPACING_LY):
			anchors.append(candidate)
	return anchors


## Places CAIRN within CAIRN_MAX_RADIUS_LY of the origin and CAIRN_MIN_ANCHOR_GAP_LY from every
## anchor. Falls back to the origin when MAX_ATTEMPTS is exhausted.
static func place_cairn(rng: RandomNumberGenerator, anchors: Array[Vector3i]) -> Vector3i:
	var half: Vector3i = Vector3i(CAIRN_MAX_RADIUS_LY, CAIRN_MAX_RADIUS_LY, HALF_EXTENT_LY.z)
	for attempt: int in MAX_ATTEMPTS:
		var candidate: Vector3i = _random_in_box(rng, half)
		if AddressRule.squared_distance(candidate, Vector3i.ZERO) > _square(CAIRN_MAX_RADIUS_LY):
			continue
		if _is_clear_of(candidate, anchors, CAIRN_MIN_ANCHOR_GAP_LY):
			return candidate
	return Vector3i.ZERO


## Picks CAIRN's origin glyph at random from the anchors that are not among its seven nearest.
static func pick_origin_glyph(
	rng: RandomNumberGenerator, position: Vector3i, anchors: Array[Vector3i]
) -> int:
	var nearest: Array[int] = AddressRule.nearest_anchors(position, anchors, -1, NEAREST_EXCLUDED)
	var allowed: Array[int] = []
	for index: int in anchors.size():
		if not nearest.has(index):
			allowed.append(index)
	return allowed[rng.randi_range(0, allowed.size() - 1)]


## Returns the `.tres` text of the home anchor field.
static func anchor_field_text(anchors: Array[Vector3i]) -> String:
	var entries: PackedStringArray = []
	for anchor: Vector3i in anchors:
		entries.append("Vector3i(%d, %d, %d)" % [anchor.x, anchor.y, anchor.z])
	return (
		'[gd_resource type="Resource" script_class="AnchorFieldDef" format=3]\n\n'
		+ '[ext_resource type="Script" path="res://src/content/anchor_field_def.gd" id="1_anchr"]\n\n'
		+ '[resource]\nscript = ExtResource("1_anchr")\ndomain_id = &"home"\n'
		+ "positions_ly = Array[Vector3i]([%s])\n" % ", ".join(entries)
		+ 'id = &"anchors_home"\n'
	)


## Returns the `.tres` text of CAIRN at [param position] with origin glyph [param origin].
static func cairn_text(position: Vector3i, origin: int) -> String:
	return (
		'[gd_resource type="Resource" script_class="WorldDef" format=3]\n\n'
		+ '[ext_resource type="Script" path="res://src/content/world_def.gd" id="1_world"]\n\n'
		+ '[resource]\nscript = ExtResource("1_world")\nname_key = &"WORLD_CAIRN_NAME"\n'
		+ "position_ly = Vector3i(%d, %d, %d)\n" % [position.x, position.y, position.z]
		+ "origin_glyph = %d\nis_home = true\n" % origin
		+ 'id = &"world_cairn"\n'
	)


static func _random_in_box(rng: RandomNumberGenerator, half: Vector3i) -> Vector3i:
	var x: int = rng.randi_range(-half.x, half.x)
	var y: int = rng.randi_range(-half.y, half.y)
	var z: int = rng.randi_range(-half.z, half.z)
	return Vector3i(x, y, z)


static func _is_clear_of(point: Vector3i, others: Array[Vector3i], gap: int) -> bool:
	for other: Vector3i in others:
		if AddressRule.squared_distance(point, other) < _square(gap):
			return false
	return true


static func _square(value: int) -> int:
	return value * value


func _write(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("gen_home_domain: cannot write %s" % path)
		return false
	file.store_string(text)
	return true
