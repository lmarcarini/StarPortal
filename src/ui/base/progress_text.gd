class_name ProgressText
extends RefCounted
## Text of a site's, demolition's or dig's progress ([SiteProgress]): the time left on a plan
## bar ("3 h", "1 d 4 h", "Queued"), the SELECTED panel's status line with the percentage, the
## level tab of a dig and the Dig button's tooltip.
## Bible: docs/content/m2-base.md section 6


## "1 d 4 h", "3 h" or "35 min" for [param ticks] in-game minutes, hours rounded up.
static func time_left(ticks: int) -> String:
	if ticks < 60:
		return _tr(&"BASE_BUILD_MINUTES").format({"n": maxi(0, ticks)})
	var hours: int = ceili(ticks / 60.0)
	if hours < 24:
		return _tr(&"BASE_BUILD_HOURS").format({"n": hours})
	if hours % 24 == 0:
		return _tr(&"BASE_BUILD_DAYS").format({"n": hours / 24})
	return _tr(&"BASE_TIME_DAYS_HOURS").format({"d": hours / 24, "h": hours % 24})


## The whole percentage done of [param progress], 0 to 100 (100 only when done).
static func percent(progress: SiteProgress) -> int:
	return clampi(floori(progress.fraction * 100.0), 0, 100)


## What a plan bar of [param progress] says: "Queued", or the time left.
static func caption(progress: SiteProgress) -> String:
	if progress.kind == SiteProgress.Kind.QUEUED:
		return _tr(&"BASE_SITE_QUEUED")
	return time_left(progress.ticks_left)


## The SELECTED panel's status for [param progress]: "Under construction: 45%, 1 d 4 h left",
## "Queued: waits for a free building slot (#2 in line)" or "Demolishing: 30%, 2 h left".
static func status(progress: SiteProgress) -> String:
	match progress.kind:
		SiteProgress.Kind.QUEUED:
			return _tr(&"BASE_STATUS_QUEUED").format({"n": progress.queue_place})
		SiteProgress.Kind.DEMOLISHING:
			return _with_time(&"BASE_STATUS_DEMOLISHING", progress)
	return _with_time(&"BASE_STATUS_BUILDING", progress)


## The Dig button's tooltip while level [param level] is dug: "Digging Level 4: 45%, 2 d left".
static func dig(level: int, progress: SiteProgress) -> String:
	return _tr(&"BASE_DIG_PROGRESS").format(
		{"n": level, "pct": percent(progress), "time": time_left(progress.ticks_left)}
	)


static func _with_time(key: StringName, progress: SiteProgress) -> String:
	return _tr(key).format({"pct": percent(progress), "time": time_left(progress.ticks_left)})


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
