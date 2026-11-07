class_name BaseSubTabs
extends TabBar
## The Base tab's sub-tabs (docs/content/m2-base.md section 6): Build (the palette, digging,
## placement and the room panel) and Energy (the energy layer's switches, charge control and
## power bar). [constant TABS] lists them in order; more sub-tabs are added there. The
## gamepad shoulders step through them like the Research tab's; past the first or last they
## leave the event to the main tabs.
## Bible: docs/content/m2-base.md section 6; docs/content/m25-lean-start.md section 3

## Emitted when the shown sub-tab changes, by a click, a shoulder or [method show_tab].
signal sub_tab_changed(tab: StringName)

const BUILD: StringName = &"build"
const ENERGY: StringName = &"energy"
## The sub-tabs in order; [constant TITLES] holds their title keys in the same order.
const TABS: Array[StringName] = [BUILD, ENERGY]
const TITLES: Array[StringName] = [&"BASE_SUBTAB_BUILD", &"BASE_SUBTAB_ENERGY"]


func _init() -> void:
	auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = FOCUS_NONE
	tab_alignment = ALIGNMENT_LEFT
	tab_changed.connect(_on_tab_changed)


## The tabs are added here: a scene sets tab_count after _init(), which would clear them.
func _ready() -> void:
	for title: StringName in TITLES:
		add_tab(tr(title))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and tab_count == TITLES.size():
		for index: int in TABS.size():
			set_tab_title(index, tr(TITLES[index]))


## Returns the id of the shown sub-tab.
func shown() -> StringName:
	return TABS[current_tab]


## Shows the sub-tab [param tab]; emits [signal sub_tab_changed] when it changes.
func show_tab(tab: StringName) -> void:
	var index: int = TABS.find(tab)
	if index >= 0:
		current_tab = index


## Moves [param offset] sub-tabs along; false, changing nothing, past the first or last.
func step(offset: int) -> bool:
	var index: int = current_tab + offset
	if index < 0 or index >= TABS.size():
		return false
	current_tab = index
	return true


## +1 for a new view_next shoulder press, -1 for view_previous, else 0. Only gamepad buttons
## count: the keyboard's view actions always change the main tab.
static func shoulder_step(event: InputEvent) -> int:
	if not event is InputEventJoypadButton:
		return 0
	if InputActions.is_new_press(event, &"view_next"):
		return 1
	if InputActions.is_new_press(event, &"view_previous"):
		return -1
	return 0


func _on_tab_changed(index: int) -> void:
	sub_tab_changed.emit(TABS[index])
