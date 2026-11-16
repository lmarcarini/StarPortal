extends SceneTree
## Writes the interface hardware textures to art/ui/hardware. Run from the project root:
## `godot --headless --path . --script tools/gen_hardware_textures.gd`, then import.
## Tool code only. Bible: docs/content/interface-rethink.md section 7 (interface hardware)


func _init() -> void:
	var images: Dictionary[String, Image] = HardwareTextures.build_all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HardwareTextures.OUT_DIR))
	for texture_name: String in images:
		var path: String = HardwareTextures.OUT_DIR.path_join(texture_name + ".png")
		images[texture_name].save_png(ProjectSettings.globalize_path(path))
		print("wrote " + path)
	quit(0)
