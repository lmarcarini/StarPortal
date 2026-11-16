class_name HwMetrics
extends RefCounted
## Sizes for the hardware kit at the current UI scale, read from the theme's body font size,
## so every control grows and shrinks with the 80 to 150% setting.
## Bible: docs/content/interface-rethink.md section 7; game-design.md#difficulty-and-accessibility

## Smallest touch target at 100%, in pixels at 1080p.
const MIN_TARGET: float = 44.0


## UI scale of [param control] (1.0 at the default body size).
static func scale_of(control: Control) -> float:
	var body: int = control.get_theme_default_font_size()
	if body <= 0:
		return 1.0
	return clampf(float(body) / float(UiThemeBuilder.BODY_SIZE), 0.5, 2.0)


## [param value] pixels at [param control]'s UI scale.
static func px(control: Control, value: float) -> float:
	return value * scale_of(control)


## Minimum size [param base] at [param control]'s scale, never under [constant MIN_TARGET].
static func target(control: Control, base: Vector2) -> Vector2:
	var s: Vector2 = base * scale_of(control)
	return Vector2(maxf(s.x, MIN_TARGET), maxf(s.y, MIN_TARGET))
