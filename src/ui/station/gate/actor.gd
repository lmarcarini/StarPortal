class_name Actor
extends RefCounted
## One moving thing on the Gate floor: a figure or a prop going along a route over time,
## starting after a delay. Routes are named, so the screen path is rebuilt from the station's
## anchors on every frame and stays right after a resize.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)

## Routes. OUT: left door, ramp foot, ramp top (into the horizon). IN: the reverse. RAMP_UP
## and RAMP_DOWN: the ramp only. STAND: still, at a console bank.
enum Route { OUT, IN, RAMP_UP, RAMP_DOWN, STAND }

## Route.
var route: Route = Route.OUT
## A FigureSprite.Kind, or -1 for a prop.
var figure: int = FigureSprite.Kind.SOLDIER
## A Props.Kind when [member figure] is -1.
var prop: int = Props.Kind.MOTH
## Seconds before it starts.
var delay: float = 0.0
## Seconds it takes.
var duration: float = 5.0
## Seconds since it was made.
var elapsed: float = 0.0
## A fade in place instead of a walk (reduced motion).
var fade_only: bool = false
## Where a STAND actor stands (a console bank's anchor name).
var spot: StringName = &""


## Progress 0..1 (0 before the delay ends).
func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf((elapsed - delay) / duration, 0.0, 1.0)


## True once it has run its course (STAND actors never finish).
func is_done() -> bool:
	return route != Route.STAND and elapsed >= delay + duration


## True while it has started.
func has_started() -> bool:
	return elapsed >= delay


## Moves on by [param seconds].
func advance(seconds: float) -> void:
	elapsed += seconds


## Jumps to the end.
func snap_to_end() -> void:
	elapsed = delay + duration
