class_name UiPalette
extends RefCounted
## Interface colours by role. Every screen takes its colours from here (through the Theme
## that UiThemeBuilder makes), so no screen picks a colour by hand.
## RING is the event-horizon blue: only the gate chip while open and the Ring view use it,
## never a theme style.
## Bible: docs/content/interface-pass.md section 2, art-and-audio.md#ui-and-typography

## Screen background: near-black grey-green.
const GROUND: Color = Color("#14181a")
## Panel fill.
const PANEL: Color = Color("#1d2326")
## Panel borders and thin rules.
const RULE: Color = Color("#39444a")
## Values and body text: off-white.
const TEXT: Color = Color("#e2e0d4")
## Labels and secondary text.
const TEXT_DIM: Color = Color("#9ca3a0")
## Selection: current tab, selected room, focus. Sodium orange.
const SELECT: Color = Color("#e8a33d")
## On, powered, gains. CRT green.
const GOOD: Color = Color("#7fd68a")
## Needs attention soon. Amber; always shown with a triangle.
const WARN: Color = Color("#d9b84a")
## Breach, failure. Klaxon red; always shown with a filled square.
const ALARM: Color = Color("#e5533d")
## Event-horizon blue. The Ring only.
const RING: Color = Color("#3fa9f5")

## Key face, a step lighter than PANEL.
const KEYCAP: Color = Color("#2a3236")
## Key face under the pointer.
const KEYCAP_HOVER: Color = Color("#333d42")
## Dark edge under a raised key.
const KEYCAP_EDGE: Color = Color("#0c0f10")
## Header strip fill, between GROUND and PANEL.
const HEADER: Color = Color("#262e31")


## WCAG contrast ratio of [param a] against [param b], from 1.0 to 21.0.
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


static func _linear(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
