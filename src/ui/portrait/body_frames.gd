class_name BodyFrames
extends RefCounted
## The pose table of the 64×128 full-body sprite (docs/content/portraits.md, "Full body"):
## every pose is plain data, a playback speed and a list of frames, and the painter draws
## whatever this table lists. A frame is a dictionary of whole-pixel values; a key left out
## means its default (DEFAULTS). Adding a pose (sit, carry, kneel, salute, limp) means
## adding an entry here, plus a limb style in BodyParts when it needs a new shape.
## Frame keys:
## - "bob": upper body (head, torso, arms) moved down this many pixels; feet never move.
## - "arms": arm style, "hang" (at the sides) or "forward" (at chest height, working).
## - "legs": leg style, "stand".
## - "step_l", "step_r": foot forward of the hip (side view), in pixels.
## - "lift_l", "lift_r": foot lifted off the baseline, in pixels.
## - "swing_l", "swing_r": hand forward of the shoulder (side view), in pixels.
## - "hand_l", "hand_r": hand moved down this many pixels (working hands).
## "l" and "r" are the person's own left and right.
## Bible: docs/content/portraits.md; art-and-audio ("Characters": walk, work and idle cycles)

## Directions drawn. "side" faces right; left-facing is the side frames with flip_h.
const DIRECTIONS: Array[String] = ["front", "back", "side"]
## Values of keys a frame leaves out.
const DEFAULTS: Dictionary[String, Variant] = {
	"bob": 0,
	"arms": "hang",
	"legs": "stand",
	"step_l": 0,
	"step_r": 0,
	"lift_l": 0,
	"lift_r": 0,
	"swing_l": 0,
	"swing_r": 0,
	"hand_l": 0,
	"hand_r": 0,
}
## The poses: name to {"fps": frames per second, "frames": Array of frame dictionaries}.
const POSES: Dictionary[String, Dictionary] = {
	"idle":
	{
		"fps": 2.0,
		"frames": [{}, {"bob": 1}],
	},
	"walk":
	{
		"fps": 6.0,
		"frames":
		[
			{"step_l": 5, "step_r": -5, "lift_r": 1, "swing_l": -4, "swing_r": 4},
			{"bob": -1, "step_l": 1, "step_r": -1, "lift_r": 3},
			{"step_l": -5, "step_r": 5, "lift_l": 1, "swing_l": 4, "swing_r": -4},
			{"bob": -1, "step_l": -1, "step_r": 1, "lift_l": 3},
		],
	},
	"work":
	{
		"fps": 3.0,
		"frames":
		[
			{"arms": "forward", "hand_l": 0, "hand_r": -2},
			{"arms": "forward", "hand_l": -2, "hand_r": 0},
		],
	},
}


## Every pose name, in table order.
static func poses() -> Array[String]:
	var names: Array[String] = []
	names.assign(POSES.keys())
	return names


## The animation name of [param pose] seen from [param direction]: "walk_back".
static func animation(pose: String, direction: String) -> String:
	return "%s_%s" % [pose, direction]


## Every animation name (pose × direction), as built into the SpriteFrames.
static func animations() -> Array[String]:
	var names: Array[String] = []
	for pose: String in POSES:
		for direction: String in DIRECTIONS:
			names.append(animation(pose, direction))
	return names


## Number of frames of [param pose]; 0 when the table has no such pose.
static func frame_count(pose: String) -> int:
	if not POSES.has(pose):
		return 0
	var frames: Array = POSES[pose]["frames"]
	return frames.size()


## Frames per second of [param pose].
static func fps(pose: String) -> float:
	if not POSES.has(pose):
		return 0.0
	var speed: float = POSES[pose]["fps"]
	return speed


## Frame [param index] of [param pose] with every key filled in from DEFAULTS.
static func frame(pose: String, index: int) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	if index < 0 or index >= frame_count(pose):
		return out
	var frames: Array = POSES[pose]["frames"]
	var given: Dictionary = frames[index]
	out.merge(given, true)
	return out
