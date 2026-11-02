class_name DigButton
extends HoldButton
## The palette's Dig button (docs/content/m2-base.md section 4): "Dig Level 2 · $1,500k ·
## 3 d", held to dig. While a level is being dug it offers to cancel the dig with its 50%
## refund instead, its tooltip showing the dig's progress ("Digging Level 4: 45%, 2 d left");
## past the last level allowed it is disabled. A refused dig shows why in its
## tooltip and in [method get_reason]. It changes no state: it emits [signal command_held].
## Bible: docs/content/m2-base.md section 4

## Emitted when a hold confirms; [param command] digs or cancels the dig.
signal command_held(command: Command)

var _command: Command = null
var _reason: String = ""


func _init() -> void:
	auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	confirmed.connect(_on_confirmed)


## Rewrites the button for [param state]: dig the next level, cancel the dig, or nothing left.
func refresh(state: GameState) -> void:
	if state.balance == null:
		_command = null
		text = tr(&"BASE_BUILD_DIG_DONE")
		disabled = true
		return
	var digging: int = state.base.digging_level()
	if digging != 0:
		var cost_k: int = DigLevelCommand.cost_k(state, digging)
		_command = CancelBuildCommand.create(CancelBuildCommand.DIG_TARGET)
		text = (
			tr(&"BASE_BUILD_DIG_CANCEL")
			. format(
				{
					"n": digging,
					"refund":
					MoneyLabel.format_k(cost_k * CancelBuildCommand.DIG_REFUND_PERCENT / 100),
				}
			)
		)
	else:
		var next: int = state.base.level_count + 1
		_command = DigLevelCommand.new()
		text = (
			tr(&"BASE_BUILD_DIG")
			. format(
				{
					"n": next,
					"cost": MoneyLabel.format_k(DigLevelCommand.cost_k(state, next)),
					"time": BuildText.duration(_dig_ticks(state, next)),
				}
			)
		)
	var result: CommandResult = _command.validate(state)
	_reason = "" if result.is_ok else _reason_of(result, state)
	if result.error_code == &"level_limit":
		text = tr(&"BASE_BUILD_DIG_DONE")
	disabled = not result.is_ok
	tooltip_text = _reason
	if digging != 0 and _reason.is_empty():
		tooltip_text = ProgressText.dig(digging, SiteProgress.of_dig(state))


## Why the button is disabled, or "".
func get_reason() -> String:
	return _reason


func _reason_of(result: CommandResult, state: GameState) -> String:
	var cost_k: int = DigLevelCommand.cost_k(state, state.base.level_count + 1)
	return BuildText.reason(result, state, cost_k)


static func _dig_ticks(state: GameState, level: int) -> int:
	var index: int = level - state.balance.starting_levels - 1
	if index < 0 or index >= state.balance.dig_level_ticks.size():
		return 0
	return state.balance.dig_level_ticks[index]


func _on_confirmed() -> void:
	if _command != null:
		command_held.emit(_command)
