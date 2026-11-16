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
	&"debug_toggle_cheats",
	&"pause_menu",
	&"view_next",
	&"view_previous",
	&"view_gate_room",
	&"view_archive",
	&"view_base",
	&"view_research",
	&"view_personnel",
	&"view_command",
	&"view_expeditions",
	&"base_level_up",
	&"base_level_down",
	&"base_energy_layer",
	&"dialog_continue",
	&"dialog_choice_1",
	&"dialog_choice_2",
	&"dialog_choice_3",
	&"dialog_choice_4",
	&"research_pan_left",
	&"research_pan_right",
	&"research_pan_up",
	&"research_pan_down",
	&"station_flip",
	&"station_pin",
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
## The gamepad View (Back) button toggles the Base tab's energy layer
## (docs/content/m2-base.md section 6), so [code]debug_toggle_overlay[/code] is F12 only.
## The shoulders switch views (the usual tab convention), so the time speed sits on the
## triggers: an axis pulled past the action's deadzone, read once per pull by
## [method Input.is_action_just_pressed_by_event].
const DEFAULTS: Dictionary = {
	&"time_toggle_pause":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_SPACE}],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_LEFT_STICK}],
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
				"kind": InputEventCodec.KIND_JOYPAD_MOTION,
				"axis": JOY_AXIS_TRIGGER_RIGHT,
				"direction": 1,
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
				"kind": InputEventCodec.KIND_JOYPAD_MOTION,
				"axis": JOY_AXIS_TRIGGER_LEFT,
				"direction": 1,
			},
		],
	},
	&"quick_save":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F8}],
		GAMEPAD: [],
	},
	&"quick_load":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F9}],
		GAMEPAD: [],
	},
	&"debug_toggle_overlay":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F12}],
		GAMEPAD: [],
	},
	&"debug_toggle_cheats":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F10}],
		GAMEPAD: [],
	},
	&"pause_menu":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_ESCAPE}],
		GAMEPAD: [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_START}],
	},
	&"view_next":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_E}],
		GAMEPAD:
		[
			{
				"kind": InputEventCodec.KIND_JOYPAD_BUTTON,
				"button_index": JOY_BUTTON_RIGHT_SHOULDER,
			},
		],
	},
	&"view_previous":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_Q}],
		GAMEPAD:
		[
			{
				"kind": InputEventCodec.KIND_JOYPAD_BUTTON,
				"button_index": JOY_BUTTON_LEFT_SHOULDER,
			},
		],
	},
	&"view_gate_room":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F1}],
		GAMEPAD: [],
	},
	&"view_archive":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F6}],
		GAMEPAD: [],
	},
	&"view_base":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F2}],
		GAMEPAD: [],
	},
	&"view_research":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F3}],
		GAMEPAD: [],
	},
	&"view_personnel":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F4}],
		GAMEPAD: [],
	},
	&"view_command":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F7}],
		GAMEPAD: [],
	},
	&"view_expeditions":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F5}],
		GAMEPAD: [],
	},
	&"base_level_up":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_PAGEUP}],
		GAMEPAD: [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_Y}],
	},
	&"base_level_down":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_PAGEDOWN}],
		GAMEPAD: [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_X}],
	},
	&"base_energy_layer":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_P}],
		GAMEPAD: [{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_BACK}],
	},
	# The dialogue screen's Continue (M4.8-04). Space is time_toggle_pause's; the screen reads
	# that action as Continue while it is up. Gamepad (A) presses the focused Continue key.
	&"dialog_continue":
	{
		KEYBOARD:
		[
			{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_ENTER},
			{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_KP_ENTER},
		],
		GAMEPAD: [],
	},
	# The dialogue screen's answers 1 to 4 (a gamepad picks them by focus and (A)).
	&"dialog_choice_1":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_1}],
		GAMEPAD: [],
	},
	&"dialog_choice_2":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_2}],
		GAMEPAD: [],
	},
	&"dialog_choice_3":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_3}],
		GAMEPAD: [],
	},
	&"dialog_choice_4":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_4}],
		GAMEPAD: [],
	},
	# Gate station destination cards: flip to the report, pin (M4.9-06).
	&"station_flip":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_F}],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_RIGHT_STICK}],
	},
	&"station_pin":
	{
		KEYBOARD: [{"kind": InputEventCodec.KIND_KEY, "physical_keycode": KEY_U}],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_BUTTON, "button_index": JOY_BUTTON_MISC1}],
	},
	# The research tree pans with the right stick (M4-32).
	&"research_pan_left":
	{
		KEYBOARD: [],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_MOTION, "axis": JOY_AXIS_RIGHT_X, "direction": -1}],
	},
	&"research_pan_right":
	{
		KEYBOARD: [],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_MOTION, "axis": JOY_AXIS_RIGHT_X, "direction": 1}],
	},
	&"research_pan_up":
	{
		KEYBOARD: [],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_MOTION, "axis": JOY_AXIS_RIGHT_Y, "direction": -1}],
	},
	&"research_pan_down":
	{
		KEYBOARD: [],
		GAMEPAD:
		[{"kind": InputEventCodec.KIND_JOYPAD_MOTION, "axis": JOY_AXIS_RIGHT_Y, "direction": 1}],
	},
}


## True if [param event] starts a press of [param action]: a key, button or action press
## that is not an echo, or the one axis motion that crossed the action's deadzone. An axis
## held past the deadzone keeps sending motion events that each count as pressed; only the
## first of them is a new press.
static func is_new_press(event: InputEvent, action: StringName) -> bool:
	if not event.is_action_pressed(action):
		return false
	if event is InputEventJoypadMotion:
		return Input.is_action_just_pressed_by_event(action, event)
	return true
