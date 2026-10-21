class_name InputActions
extends RefCounted
## Every named player action and its default bindings. [code]InputService[/code] registers
## these in [InputMap] at start-up; no action is declared in project.godot.
## Keys are bound by physical keycode, so they keep their position on any keyboard layout.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## game-design.md#difficulty-and-accessibility

## Key of the keyboard and mouse bindings in [constant DEFAULTS] and in stored bindings.
const KEYBOARD: StringName = &"keyboard"
## Key of the gamepad bindings in [constant DEFAULTS] and in stored bindings.
const GAMEPAD: StringName = &"gamepad"

## Every action, in the order a rebinding screen lists them.
const ACTIONS: Array[StringName] = [
	&"time_toggle_pause",
	&"time_faster",
	&"time_slower",
	&"quick_save",
	&"quick_load",
	&"debug_toggle_overlay",
]

## Gamepad bindings added to Godot's built-in UI actions at start-up, as {action: [encoded]},
## so a gamepad can press (A) and cancel (B) focused controls. The built-in keyboard bindings
## of these actions stay. They are not rebindable.
const UI_GAMEPAD_DEFAULTS: Dictionary = {
	&"ui_accept": [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_A}],
	&"ui_cancel": [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_B}],
}

## Default bindings as {action: {KEYBOARD: [encoded], GAMEPAD: [encoded]}}, each event
## encoded by [InputEventCodec], at most [code]InputService.BINDINGS_PER_DEVICE[/code] each.
## The gamepad chord Back + Right stick press for [code]debug_toggle_overlay[/code] cannot be
## bound in [InputMap], so its default is Back alone.
const DEFAULTS: Dictionary = {
	&"time_toggle_pause":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_SPACE}],
		GAMEPAD: [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_START}],
	},
	&"time_faster":
	{
		KEYBOARD:
		[
			{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_EQUAL},
			{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_KP_ADD},
		],
		GAMEPAD:
		[
			{
				"kind": InputEventCodec.KIND_JOYPAD_BUTTON,
				"button_index": JOY_BUTTON_RIGHT_SHOULDER,
			},
		],
	},
	&"time_slower":
	{
		KEYBOARD:
		[
			{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_MINUS},
			{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_KP_SUBTRACT},
		],
		GAMEPAD:
		[
			{
				"kind": InputEventCodec.KIND_JOYPAD_BUTTON,
				"button_index": JOY_BUTTON_LEFT_SHOULDER,
			},
		],
	},
	&"quick_save":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F5}],
		GAMEPAD: [],
	},
	&"quick_load":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F9}],
		GAMEPAD: [],
	},
	&"debug_toggle_overlay":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F3}],
		GAMEPAD: [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_BACK}],
	},
}
