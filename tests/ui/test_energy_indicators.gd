## Tests for the energy overlay fixes (issue #157): every built room type is labelled on the
## plan and tagged on the energy layer in English and Brazilian Portuguese, an unpowered room
## has a shape as well as a colour, the bar shows "no spare power" and outlines its spare part
## after a refusal (steady with reduced flashing), and the capacitor line says empty and
## "Not charging".
## Bible: docs/content/m2-base.md sections 3 and 6
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## Rooms with no power role, so no tag on the layer: circulation and the Quarters (no draw).
const NO_TAG: Array[StringName] = [&"room_corridor", &"room_lift", &"room_stairs", &"room_quarters"]

var _real_locale: String = ""
var _real_flashing: bool = false
var _font: Font = null
var _state: GameState = null


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	_real_flashing = Settings.get_bool(&"accessibility", &"reduced_flashing")
	var probe: Control = auto_free(Control.new())
	_font = probe.get_theme_default_font()
	_state = ConstructionFixture.state()


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)
	Settings.set_value(&"accessibility", &"reduced_flashing", _real_flashing)


## The Oficina bug: in both languages every room type's whole name fits its floor as built
## (and turned, when 3 or more cells wide), never dropped; a turned 2-cell-wide room is cut
## with "…" at worst, never blank.
func test_every_room_name_label_fits_in_both_languages() -> void:
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		for def: RoomDef in _state.room_defs.values():
			if def.id == StartingBase.CORRIDOR_DEF:
				continue
			var name: String = TranslationServer.translate(def.name_key).to_upper()
			for cells: Vector2i in _orientations(def):
				var lines: Array = (
					PlanLabel.fit(name, Vector2(cells) * BasePlanPainter.CELL, _font)["lines"]
				)
				var shown: String = " ".join(PackedStringArray(lines))
				(
					assert_str(shown)
					. override_failure_message("%s %s %s" % [locale, def.id, cells])
					. is_not_empty()
				)
				if mini(cells.x, cells.y) >= 3 or cells == def.size_cells:
					(
						assert_str(shown)
						. override_failure_message("%s %s %s" % [locale, def.id, cells])
						. is_equal(name)
					)


## Every built room type with a power role gets a tag on the energy layer in both languages.
func test_every_built_room_type_has_an_overlay_tag_in_both_languages() -> void:
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		for def: RoomDef in _state.room_defs.values():
			var room := RoomState.create(&"probe", def.id, 1, Vector2i.ZERO)
			var tag: String = PowerText.tag(_state, room, def)
			if def.id in NO_TAG:
				assert_str(tag).is_empty()
			else:
				assert_str(tag).override_failure_message("%s %s" % [locale, def.id]).is_not_empty()


## A switched-off room and a refused one are unpowered on the layer; a running one is not.
func test_layer_marks_unpowered_rooms() -> void:
	var layer: EnergyLayer = auto_free(EnergyLayer.new())
	var plan: BasePlan = auto_free(BasePlan.new())
	layer.setup(plan, _state)
	var archive: RoomState = PowerFixture.lab(_state)
	var gate: RoomState = PowerFixture.first_room(_state, &"room_gate")
	assert_bool(layer.is_unpowered(archive.id)).is_false()
	archive.powered_on = false
	assert_bool(layer.is_unpowered(archive.id)).is_true()
	assert_bool(layer.is_unpowered(gate.id)).is_false()
	archive.powered_on = true
	layer.mark_refused(archive.id, 1.0)
	assert_bool(layer.is_unpowered(archive.id)).is_true()


## With 0 MW spare the bar and the strip say so; a refusal outlines the spare part, blinking,
## or steadily with reduced flashing.
func test_no_spare_power_and_refusal_outline() -> void:
	var strip: PowerStrip = auto_free(PowerStrip.new())
	add_child(strip)
	TranslationServer.set_locale("en")
	strip.show_state(_state, false)
	assert_bool(strip.bar.has_no_spare()).is_false()
	PowerFixture.add_bank(_state, roundi(PowerRules.spare_mw(_state)))
	strip.show_state(_state, false)
	assert_bool(strip.bar.has_no_spare()).is_true()
	assert_str(strip.texts()[0]).is_equal("30 MW · No spare power")
	TranslationServer.set_locale("pt_BR")
	strip.show_state(_state, false)
	assert_str(strip.texts()[0]).is_equal("30 MW · Sem energia livre")
	Settings.set_value(&"accessibility", &"reduced_flashing", false)
	strip.bar.flash_spare()
	assert_bool(strip.bar.is_spare_outlined()).is_true()
	strip.bar._process(PowerBar.BLINK_SECONDS + 0.01)
	assert_bool(strip.bar.is_spare_outlined()).is_false()
	Settings.set_value(&"accessibility", &"reduced_flashing", true)
	assert_bool(strip.bar.is_spare_outlined()).is_true()
	strip.bar._process(PowerBar.FLASH_SECONDS)
	assert_bool(strip.bar.is_spare_outlined()).is_false()


## The capacitor line: empty and not charging, empty and charging, not charging.
func test_capacitor_line_says_empty_and_not_charging() -> void:
	TranslationServer.set_locale("en")
	PowerFixture.add_bank(_state, 0)
	_state.power.stored_mwh = 0.0
	assert_str(PowerText.capacitors(_state)).is_equal("Capacitors empty (0/400 MWh), Not charging")
	PowerFixture.set_charge(_state, 20)
	assert_str(PowerText.capacitors(_state)).is_equal("Capacitors empty (0/400 MWh), full in 20 h")
	PowerFixture.set_charge(_state, 0)
	_state.power.stored_mwh = 100.0
	assert_str(PowerText.capacitors(_state)).is_equal("Capacitors 100/400 MWh, Not charging")
	TranslationServer.set_locale("pt_BR")
	_state.power.stored_mwh = 0.0
	assert_str(PowerText.capacitors(_state)).is_equal(
		"Capacitores vazios (0/400 MWh), Sem carregar"
	)


static func _orientations(def: RoomDef) -> Array[Vector2i]:
	var turned := Vector2i(def.size_cells.y, def.size_cells.x)
	if def.rotatable and turned != def.size_cells:
		return [def.size_cells, turned]
	return [def.size_cells]


## The layer covers the whole plan, also after the plan is resized: its dimming once stopped
## at the plan's first size.
func test_layer_follows_the_plan_size() -> void:
	var plan: BasePlan = auto_free(BasePlan.new())
	add_child(plan)
	var layer := EnergyLayer.new()
	plan.add_child(layer)
	plan.size = Vector2(900, 500)
	assert_vector(layer.size).is_equal(plan.size)
