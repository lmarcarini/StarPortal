class_name PortraitDef
extends DefBase
## How to draw a speaker in the dialogue screen's portrait window: a kind (which renderer
## draws it; only &"placeholder" for now), that kind's parameters, and whether it is a still
## (a fixed picture: no breathing, blinking or mouth). Later kinds slot in behind the same
## window (docs/content/dialogue-screen.md section 3). Read only at runtime.
## Bible: docs/content/dialogue-screen.md sections 3 and 7

## Kinds a renderer exists for.
const KINDS: Array[StringName] = [&"placeholder"]
## Placeholder parameters that are colours.
const COLOUR_PARAMS: Array[String] = ["skin", "hair", "clothing", "accent"]
## Placeholder parameter that is a number from 0 (slight) to 1 (broad).
const BUILD_PARAM: String = "build"

## Which renderer draws it.
@export var kind: StringName = &"placeholder"
## The kind's parameters. Placeholder: "skin", "hair", "clothing", "accent" (Colors) and
## "build" (0..1); any may be left out.
@export var params: Dictionary = {}
## A fixed picture shown through the same video look, with no animation.
@export var still: bool = false


## The colour parameter [param key], or [param fallback] when it is not set.
func colour(key: String, fallback: Color) -> Color:
	var value: Variant = params.get(key)
	return value if value is Color else fallback


## The build, 0..1 (0.5 when not set).
func build() -> float:
	var value: Variant = params.get(BUILD_PARAM)
	if not (value is float or value is int):
		return 0.5
	var number: float = value
	return clampf(number, 0.0, 1.0)


## A known kind and well-formed placeholder parameters.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if not KINDS.has(kind):
		errors.append("unknown portrait kind '%s'" % kind)
		return errors
	for key: Variant in params:
		var value: Variant = params[key]
		if COLOUR_PARAMS.has(str(key)):
			if not value is Color:
				errors.append("param '%s' is not a colour" % key)
		elif str(key) == BUILD_PARAM:
			if not _is_unit_number(value):
				errors.append("param 'build' is not a number from 0 to 1")
		else:
			errors.append("unknown param '%s'" % key)
	return errors


static func _is_unit_number(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	var number: float = value
	return number >= 0.0 and number <= 1.0
