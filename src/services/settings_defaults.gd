class_name SettingsDefaults
extends RefCounted
## Default value of every player setting, as {section: {key: default}}.
## This table is the only gate for [code]Settings[/code]: a section or key that is not here
## cannot be read or written, and each default's type is the type its setting must keep.
## A later card adds its own section (for example [code]input[/code]) by extending this table.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## game-design.md#difficulty-and-accessibility

## Every setting with its default value. Keys are StringNames.
const VALUES: Dictionary = {
	&"display":
	{
		&"ui_scale": 1.0,
		&"text_size": 1.0,
		&"screen_grain": true,
		&"ambient_movement": true,
	},
	&"audio":
	{
		&"master": 1.0,
		&"music": 0.8,
		&"effects": 1.0,
		&"voice": 1.0,
		&"ambience": 0.8,
	},
	&"accessibility":
	{
		&"subtitles": true,
		&"reduced_flashing": false,
		&"screen_shake": true,
	},
	&"gameplay":
	{
		&"language": "en",
		# On a lock, switch to the Gate Room and operate the gate (docs/content/event-time.md 3).
		&"switch_to_gate_on_lock": true,
		# Failure states (M4c-14): off for free play and testing; nothing can end the game.
		&"failure_states": true,
		# Open the team report by itself when a team comes home (M4.9-15).
		&"auto_open_team_report": true,
	},
	# One key per InputActions.ACTIONS entry, holding that action's bindings encoded by
	# InputService. An empty Dictionary means "use the built-in defaults".
	&"input":
	{
		&"time_toggle_pause": {},
		&"time_faster": {},
		&"time_slower": {},
		&"quick_save": {},
		&"quick_load": {},
		&"debug_toggle_overlay": {},
		&"debug_toggle_cheats": {},
		&"pause_menu": {},
		&"view_next": {},
		&"view_previous": {},
		&"view_gate_room": {},
		&"view_base": {},
		&"view_research": {},
		&"view_office": {},
		&"base_level_up": {},
		&"base_level_down": {},
		&"base_energy_layer": {},
		&"dialog_continue": {},
		&"dialog_choice_1": {},
		&"dialog_choice_2": {},
		&"dialog_choice_3": {},
		&"dialog_choice_4": {},
		&"research_pan_left": {},
		&"research_pan_right": {},
		&"research_pan_up": {},
		&"research_pan_down": {},
		&"station_flip": {},
		&"station_pin": {},
		&"station_rail_5": {},
	},
}
