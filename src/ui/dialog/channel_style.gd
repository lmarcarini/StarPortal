class_name ChannelStyle
extends RefCounted
## The portrait window's look per channel (docs/content/dialogue-screen.md section 3): every
## channel uses the same video look; only the label and the frame accent change. The Ring (a
## hail or an answered incoming wormhole) has a Ring-blue frame, the one place that blue appears
## outside the gate; the Earth secure line a CRT-green one.
## Bible: docs/content/dialogue-screen.md section 3


## The frame accent of [param channel].
static func accent(channel: StringName) -> Color:
	return UiPalette.GOOD if channel == &"phone" else UiPalette.RING


## The window's label: "VIDEO LINK · RING · LINTEL" or "VIDEO LINK · SECURE LINE".
static func label(channel: StringName, world_name: String) -> String:
	if channel == &"phone":
		return tr_key(&"DIALOG_VIDEO_SECURE")
	return tr_key(&"DIALOG_VIDEO_RING").format({"world": world_name.to_upper()})


## "LIVE" for a moving portrait, "STILL" for a still.
static func state_label(still: bool) -> String:
	return tr_key(&"DIALOG_VIDEO_STILL" if still else &"DIALOG_VIDEO_LIVE")


## [param key] in the current locale.
static func tr_key(key: StringName) -> String:
	return String(TranslationServer.translate(key))
