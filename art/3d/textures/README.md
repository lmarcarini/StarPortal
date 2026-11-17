# Hall textures (CC0 PBR)

One folder per set, each with `albedo.png`, `normal.png` (OpenGL convention) and
`roughness.png`, 1K: `concrete_wall`, `concrete_floor`, `painted_metal`, `metal_plates`,
`diamond_plate`. `src/scenes/stations/gate_hall.gd` picks them up; a missing file leaves the
flat material in place. Rebake the hall's lightmap after adding them.
