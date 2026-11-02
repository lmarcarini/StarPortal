## Tests for the top bar money display: formatting, red below zero, updates on budget_changed,
## and the shell showing a new game's budget.
## Bible: docs/content/m2-base.md section 5
extends GdUnitTestSuite

const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"


func test_format() -> void:
	assert_str(MoneyLabel.format_k(12000)).is_equal("$12,000k")
	assert_str(MoneyLabel.format_k(0)).is_equal("$0k")
	assert_str(MoneyLabel.format_k(240)).is_equal("$240k")
	assert_str(MoneyLabel.format_k(-1234567)).is_equal("-$1,234,567k")


func test_updates_on_budget_changed_and_turns_red() -> void:
	var label: MoneyLabel = auto_free(MoneyLabel.new())
	add_child(label)
	EventBus.budget_changed.emit(-240)
	assert_str(label.text).is_equal("-$240k")
	assert_bool(label.has_theme_color_override(&"font_color")).is_true()
	EventBus.budget_changed.emit(500)
	assert_str(label.text).is_equal("$500k")
	assert_bool(label.has_theme_color_override(&"font_color")).is_false()
	remove_child(label)


func test_shell_shows_the_starting_budget() -> void:
	var real_saves_dir: String = SaveService.saves_dir
	SaveService.saves_dir = "user://test_money_saves_%d" % Time.get_ticks_usec()
	var shell: Node = (load(SHELL_SCENE) as PackedScene).instantiate()
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	var label: MoneyLabel = shell.get_node("%MoneyLabel")
	assert_str(label.text).is_equal("$6,000k")
	shell.free()
	SaveService.saves_dir = real_saves_dir
