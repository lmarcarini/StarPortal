class_name WorkbenchPicker
extends RefCounted
## Click-to-pick state of the Address Workbench, as an explicit state machine. View-local:
## nothing here is game state, and nothing is saved.
##
## | Mode           | Waiting for                     | Next pick                   |
## | IDLE           | a glyph                         | the glyph becomes picked    |
## | GLYPH_PICKED   | a seal slot or an action        | another glyph replaces it   |
## | AWAIT_NOT_AT   | the seal the glyph is not at    | (a seal ends it)            |
## | AWAIT_FARTHER  | the glyph the first is nearer   | (a glyph ends it)           |
## Bible: game-design.md#difficulty-and-accessibility (click-to-pick and click-to-place),
## gate-and-address-spec.md#player-tools

## What the workbench waits for next.
enum Mode { IDLE, GLYPH_PICKED, AWAIT_NOT_AT, AWAIT_FARTHER }

## The current mode.
var mode: Mode = Mode.IDLE
## The picked glyph, 0..35, or -1 in IDLE.
var glyph: int = -1


## Picks [param picked]; picking the picked glyph again in GLYPH_PICKED drops it.
func pick(picked: int) -> void:
	if mode == Mode.GLYPH_PICKED and picked == glyph:
		cancel()
		return
	mode = Mode.GLYPH_PICKED
	glyph = picked


## Starts waiting for the seal the picked glyph is not at. Ignored without a picked glyph.
func await_not_at() -> void:
	if glyph >= 0:
		mode = Mode.AWAIT_NOT_AT


## Starts waiting for the glyph the picked glyph is nearer than. Ignored without one.
func await_farther() -> void:
	if glyph >= 0:
		mode = Mode.AWAIT_FARTHER


## Back to IDLE with nothing picked.
func cancel() -> void:
	mode = Mode.IDLE
	glyph = -1


## True while a glyph is picked, in any mode but IDLE.
func has_glyph() -> bool:
	return mode != Mode.IDLE
