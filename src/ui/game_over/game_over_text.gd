class_name GameOverText
extends RefCounted
## The words of the game over screen (M4c-15): the cause with a line of explanation, the
## date, and three figures.
## Bible: docs/content/m4c-incursions.md section 8


## The title for [param cause]: "OVERRUN", "SHUT DOWN" or "BANKRUPT".
static func title(cause: StringName) -> String:
	return _tr(StringName("GAME_OVER_%s" % String(cause).to_upper()))


## The line explaining [param cause].
static func explanation(cause: StringName) -> String:
	return _tr(StringName("GAME_OVER_%s_LINE" % String(cause).to_upper()))


## The date the game ended, as the expedition screens write dates.
static func date(state: GameState) -> String:
	return ExpeditionText.date(state.outcome.tick)


## "Days survived: 42 · Worlds locked: 5 · Research done: 9".
static func figures(state: GameState) -> String:
	var days: int = TimeMath.day_index(state.outcome.tick) + 1
	return (
		_tr(&"GAME_OVER_FIGURES")
		. format(
			{
				"days": days,
				"worlds": ConfidenceRules.locked_worlds(state).size(),
				"research": state.research.done.size(),
			}
		)
	)


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
