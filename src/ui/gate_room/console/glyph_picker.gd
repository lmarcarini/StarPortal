class_name GlyphPicker
extends RefCounted
## Click-to-pick state of the dial console, as an explicit state machine. View-local: nothing
## here is game state, and nothing is saved.
##
## | Mode         | Waiting for       | Next pick                                     |
## | IDLE         | a glyph           | the glyph becomes picked                      |
## | GLYPH_PICKED | a seal slot       | another glyph replaces it; the same one drops |
## Bible: game-design.md#difficulty-and-accessibility (click-to-pick and click-to-place),
## gate-and-address-spec.md#the-dial-console

## What the console waits for next.
enum Mode { IDLE, GLYPH_PICKED }

## The current mode.
var mode: Mode = Mode.IDLE
## The picked glyph, 0..35, or -1 in IDLE.
var glyph: int = -1


## Picks [param picked]; picking the picked glyph again drops it.
func pick(picked: int) -> void:
	if mode == Mode.GLYPH_PICKED and picked == glyph:
		cancel()
		return
	mode = Mode.GLYPH_PICKED
	glyph = picked


## Back to IDLE with nothing picked.
func cancel() -> void:
	mode = Mode.IDLE
	glyph = -1


## True while a glyph is picked.
func has_glyph() -> bool:
	return mode == Mode.GLYPH_PICKED
