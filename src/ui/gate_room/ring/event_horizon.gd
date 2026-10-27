class_name EventHorizon
extends Control
## The event horizon inside the Ring (placeholder art drawn in code): a disc of event-horizon
## blue, the only saturated blue in the Gate Room, with slow ripples moving outwards (the
## shimmer) and a brighter wash for the opening burst. Draws only; RingView sets
## [member level], [member burst] and [member phase]. Cheap: a few circles and arcs, no shader.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## overview.md#locked-decisions (Presentation: hybrid)

## Event-horizon blue.
const HORIZON_BLUE: Color = Color(0.22, 0.52, 0.96)
## The burst's wash colour: the same blue, lighter.
const BURST_COLOR: Color = Color(0.7, 0.85, 1.0)
## Ripples on the disc at once, and the real seconds one takes to cross it.
const RIPPLES: int = 5
const RIPPLE_SECONDS: float = 3.0
const _ARC_POINTS: int = 64
const _RIPPLE_WIDTH: float = 3.0
const _RIPPLE_ALPHA: float = 0.35

## How much of the horizon shows, 0 (dark) to 1 (open).
var level: float = 0.0:
	set(value):
		level = clampf(value, 0.0, 1.0)
		queue_redraw()
## The opening burst's strength, 0 to 1.
var burst: float = 0.0:
	set(value):
		burst = clampf(value, 0.0, 1.0)
		queue_redraw()
## Real seconds of shimmer so far; moves the ripples.
var phase: float = 0.0:
	set(value):
		phase = fmod(value, RIPPLE_SECONDS)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var radius: float = RingView.horizon_radius(size)
	if level <= 0.0 or radius <= 0.0:
		return
	var center: Vector2 = size / 2.0
	draw_circle(center, radius, Color(HORIZON_BLUE.darkened(0.35), level))
	for index: int in RIPPLES:
		var share: float = fmod(float(index) / RIPPLES + phase / RIPPLE_SECONDS, 1.0)
		var alpha: float = _RIPPLE_ALPHA * sin(share * PI) * level
		var color: Color = Color(HORIZON_BLUE.lightened(0.2), alpha)
		draw_arc(center, radius * share, 0.0, TAU, _ARC_POINTS, color, _RIPPLE_WIDTH, true)
	draw_circle(center, radius * 0.35, Color(HORIZON_BLUE, 0.4 * level))
	if burst > 0.0:
		draw_circle(center, radius, Color(BURST_COLOR, burst * level))
