## The committed hardware textures match what tools/gen_hardware_textures.gd draws.
## Bible: docs/content/interface-rethink.md section 7 (interface hardware)
extends GdUnitTestSuite


func test_committed_textures_match_generator() -> void:
	var built: Dictionary[String, Image] = HardwareTextures.build_all()
	assert_int(built.size()).is_equal(HardwareTextures.NAMES.size())
	for texture_name: String in HardwareTextures.NAMES:
		var path: String = HardwareTextures.OUT_DIR.path_join(texture_name + ".png")
		var committed: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_object(committed).override_failure_message(path).is_not_null()
		committed.convert(Image.FORMAT_RGBA8)
		(
			assert_bool(committed.get_data() == built[texture_name].get_data())
			. override_failure_message(path)
			. is_true()
		)
