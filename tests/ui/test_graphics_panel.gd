## The pause menu's GRAPHICS section (#528): the keys write the display settings (saved at
## once), the quality switch shows one side amber, and switching 3D off shows the plate at
## once and on brings the hall back, with the Ring following.
## Bible: docs/content/interface-reference.md section 3
extends GdUnitTestSuite

const SCENE: PackedScene = preload("res://src/ui/station/station_scene.tscn")
const Fixture := preload("res://tests/ui/gate_room_fixture.gd")


func after_test() -> void:
	Station3D.force_enabled = false
	Station3D.skip_lightmaps = false
	for key: StringName in [&"stations_3d", &"screen_grain", &"ambient_movement", &"quality"]:
		Settings.set_value(&"display", key, SettingsDefaults.VALUES[&"display"][key])


func test_keys_write_the_settings() -> void:
	var panel: GraphicsPanel = auto_free(GraphicsPanel.new())
	add_child(panel)
	var grain: bool = Settings.get_bool(&"display", &"screen_grain")
	panel.toggle(&"screen_grain")
	assert_bool(Settings.get_bool(&"display", &"screen_grain")).is_equal(not grain)
	assert_bool(panel.is_on(&"screen_grain")).is_equal(not grain)
	panel.toggle(&"ambient_movement")
	assert_bool(panel.is_on(&"ambient_movement")).is_true()
	panel.get_buttons()[3].pressed.emit()
	assert_str(str(Settings.get_value(&"display", &"quality"))).is_equal("low")
	assert_int(panel.get_buttons().size()).is_equal(5)


func test_switching_3d_is_live() -> void:
	Station3D.skip_lightmaps = true
	var station: StationScene = auto_free(SCENE.instantiate() as StationScene)
	add_child(station)
	station.size = Vector2(1920, 1080)
	Settings.set_value(&"display", &"stations_3d", true)
	Station3D.force_enabled = true
	station.setup(Registry.get_def(&"station_gate") as StationSceneDef)
	var simulation: Simulation = Fixture.simulation()
	var ring: RingLayer = RingLayer.install(station, simulation)
	assert_object(ring.ring_3d).is_not_null()
	Station3D.force_enabled = false
	Settings.set_value(&"display", &"stations_3d", false)
	assert_object(station.get_3d()).is_null()
	assert_object(ring.ring_3d).is_null()
	assert_bool((station.find_child("Horizon", true, false) as CanvasItem).visible).is_true()
	Station3D.force_enabled = true
	Settings.set_value(&"display", &"stations_3d", true)
	assert_object(station.get_3d()).is_not_null()
	assert_object(ring.ring_3d).is_not_null()
