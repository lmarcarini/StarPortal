#!/usr/bin/env python3
"""Generates src/scenes/stations/gate_hall.tscn, the Gate hall of M5-02.

Usage: python3 tools/m5/gen_hall.py src/scenes/stations/gate_hall.tscn
The art target is art/plates/gate_hall.png from the camera in data/stations/station_gate.tres.
"""
import math, sys
OUT = sys.argv[1]
ext = []      # (type, path, id)
subs = []     # text blocks
nodes = []    # text blocks
def ext_id(t, path):
    for e in ext:
        if e[1] == path: return e[2]
    i = "e%d" % (len(ext) + 1); ext.append((t, path, i)); return i
def sub(t, props):
    i = "s%d" % (len(subs) + 1)
    body = "\n".join("%s = %s" % kv for kv in props.items())
    subs.append('[sub_resource type="%s" id="%s"]\n%s\n' % (t, i, body)); return i
def xf(pos, rot_y=0.0, scale=(1,1,1), rot_x=0.0, rot_z=0.0):
    # basis = Ry * Rx * Rz * S
    def mm(a, b): return [[sum(a[r][k]*b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]
    cy, sy = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    cx, sx = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
    cz, sz = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
    Ry = [[cy,0,sy],[0,1,0],[-sy,0,cy]]
    Rx = [[1,0,0],[0,cx,-sx],[0,sx,cx]]
    Rz = [[cz,-sz,0],[sz,cz,0],[0,0,1]]
    S = [[scale[0],0,0],[0,scale[1],0],[0,0,scale[2]]]
    B = mm(mm(mm(Ry, Rx), Rz), S)
    cols = [B[r][c] for r in range(3) for c in range(3)]
    return "Transform3D(%s)" % ", ".join("%.4g" % v for v in cols + list(pos))
def node(name, typ, parent, props, groups=None, inst=None):
    head = '[node name="%s"' % name
    if typ: head += ' type="%s"' % typ
    head += ' parent="%s"' % parent
    if groups: head += ' groups=[%s]' % ", ".join('"%s"' % g for g in groups)
    if inst: head += ' instance=ExtResource("%s")' % inst
    head += "]"
    body = "\n".join("%s = %s" % kv for kv in props.items())
    nodes.append(head + ("\n" + body if body else "") + "\n")
MAT = lambda n: 'ExtResource("%s")' % ext_id("Material", "res://src/scenes/stations/materials/%s.tres" % n)
_boxes = {}
def box(name, size, pos, mat, parent="Shell", rot_x=0.0, rot_y=0.0, rot_z=0.0):
    key = tuple(size)
    if key not in _boxes:
        _boxes[key] = sub("BoxMesh", {"size": "Vector3(%g, %g, %g)" % tuple(size), "add_uv2": "true"})
    node(name, "MeshInstance3D", parent, {"transform": xf(pos, rot_y, rot_x=rot_x, rot_z=rot_z), "mesh": 'SubResource("%s")' % _boxes[key], "material_override": MAT(mat)})
def kit(name, piece, pos, rot_y=0.0, scale=(1,1,1), parent="Kit"):
    i = ext_id("PackedScene", "res://art/3d/megakit/%s.gltf" % piece)
    node(name, None, parent, {"transform": xf(pos, rot_y, scale)}, groups=["kit"], inst=i)
def marker(name, pos, radius=None, parent="Markers"):
    p = {"transform": xf(pos)}
    if radius is not None: p["metadata/radius"] = "%g" % radius
    node(name, "Marker3D", parent, p)
def path(name, pts, parent="Markers"):
    data = []
    for p in pts: data += [0,0,0, 0,0,0, *p]
    c = sub("Curve3D", {"_data": '{\n"points": PackedVector3Array(%s),\n"tilts": PackedFloat32Array(%s)\n}' % (", ".join("%g" % v for v in data), ", ".join("0" for _ in pts)), "point_count": str(len(pts))})
    node(name, "Path3D", parent, {"curve": 'SubResource("%s")' % c})

# ---------------- layout ----------------
# Art target: art/plates/gate_hall.png seen from the camera (0, 3.3, 20) looking level, fov 50.
RING_Y = 4.9; R_IN = 2.9; R_OUT = 3.7; PED = 0.9; CW = 5.0
env = sub("Environment", {
    "background_mode": "1", "background_color": "Color(0, 0, 0, 1)",
    "ambient_light_source": "2", "ambient_light_color": "Color(0.42, 0.46, 0.52, 1)", "ambient_light_energy": "1.0",
    "tonemap_mode": "3", "tonemap_exposure": "2.3", "tonemap_white": "6.0",
    "glow_enabled": "true", "glow_intensity": "0.6", "glow_bloom": "0.02", "glow_hdr_threshold": "1.0",
    "fog_enabled": "true", "fog_light_color": "Color(0.09, 0.085, 0.08, 1)", "fog_density": "0.006",
    "adjustment_enabled": "true", "adjustment_saturation": "0.8", "adjustment_contrast": "1.08",
})
node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("%s")' % env})
for g in ["Shell", "Kit", "Ring", "Lights", "Markers"]:
    node(g, "Node3D", ".", {})
# shell: floor, ceiling, back walls (outer, dark), side walls
box("Floor", (36, 0.4, 34), (0, -0.2, 11), "floor")
for i, (x, z) in enumerate([(-10, 4), (9, 12), (-6, 18), (12, 2)]):
    box("FloorPatch%d" % i, (6, 0.02, 5), (x, 0.004, z), "floor_b")
box("Ceiling", (36, 0.4, 34), (0, 15.2, 11), "gunmetal")
box("BackOuterL", (12, 15, 0.8), (-11, 7.5, -4.4), "concrete_dark")
box("BackOuterR", (12, 15, 0.8), (11, 7.5, -4.4), "concrete_dark")
box("WallLeft", (0.8, 15, 34), (-17.4, 7.5, 11), "concrete_dark")
box("WallRight", (0.8, 15, 34), (17.4, 7.5, 11), "concrete_dark")
# the Ring's wall: a concrete panel between two steel pilasters, with seams
box("RingWall", (10.4, 15, 0.8), (0, 7.5, -1.8), "plates")
for side in (-1, 1):
    box("Pilaster%d" % side, (1.3, 15, 1.4), (side * 5.85, 7.5, -1.4), "gunmetal")
    box("PilasterFace%d" % side, (0.9, 15, 0.1), (side * 5.85, 7.5, -0.65), "concrete")
    box("Brace%d" % side, (0.8, 5.0, 0.8), (side * 4.2, 12.6, -1.2), "gunmetal", rot_z=side * 35)
    box("SideBay%d" % side, (0.8, 15, 3.0), (side * 6.6, 7.5, -3.0), "concrete_dark")
box("Lintel", (10.4, 1.0, 1.2), (0, 14.2, -1.2), "gunmetal")
# ceiling beams, cable trays and pipe runs
for z in (-0.5, 5.5, 11.5):
    box("Beam%g" % z, (34, 0.9, 0.7), (0, 14.4, z), "gunmetal")
for side in (-1, 1):
    box("Tray%d" % side, (0.9, 0.12, 30), (side * 9.0, 13.6, 10), "gunmetal")
    for k in range(5):
        kit("Cable%d_%d" % (side, k), "Prop_Cable_1", (side * 9.0, 13.68, -2 + k * 6.5), 0, (0.8, 1, 3.6))
pipe = sub("CylinderMesh", {"add_uv2": "true", "top_radius": "0.28", "bottom_radius": "0.28", "height": "30", "radial_segments": "12"})
for i, (x, y) in enumerate([(12.5, 12.6), (13.4, 12.2), (-12.8, 12.8)]):
    node("Pipe%d" % i, "MeshInstance3D", "Shell", {"transform": xf((x, y, 10), rot_x=90), "mesh": 'SubResource("%s")' % pipe, "material_override": MAT("gunmetal")})
# pedestal, ramp, railings and the hazard border at the ramp's foot
box("Pedestal", (12, PED, 2.6), (0, PED / 2, -0.2), "gunmetal")
L = 7.0; ang = math.degrees(math.atan2(PED, L)); RW = 4.2
box("Ramp", (RW, 0.2, math.hypot(L, PED)), (0, PED / 2 - 0.1, 1.1 + L / 2), "tread", rot_x=ang)
for side in (-1, 1):
    for k in range(5):
        z = 1.2 + k * 1.7; y = PED - PED * (z - 1.1) / L
        box("RampPost%d_%d" % (side, k), (0.07, 1.05, 0.07), (side * RW / 2, y + 0.52, z), "rail")
    for h in (0.55, 1.05):
        box("RampRail%d_%g" % (side, h), (0.06, 0.06, math.hypot(L, PED)), (side * RW / 2, PED / 2 + h, 1.1 + L / 2), "rail", rot_x=ang)
node("Hazard", "Node3D", "Shell", {})
for nm, size, pos in (("Foot", (RW + 2.4, 0.7), (0, 0.01, 8.6)), ("SideL", (0.7, 7.6), (-(RW / 2 + 0.85), 0.01, 4.9)), ("SideR", (0.7, 7.6), (RW / 2 + 0.85, 0.01, 4.9))):
    q = sub("PlaneMesh", {"add_uv2": "true", "size": "Vector2(%g, %g)" % size})
    node("Hazard" + nm, "MeshInstance3D", "Shell/Hazard", {"transform": xf(pos), "mesh": 'SubResource("%s")' % q, "material_override": MAT("hazard")})
line = sub("PlaneMesh", {"add_uv2": "true", "size": "Vector2(30, 0.12)"})
for z in (10.2, 14.0):
    node("FloorLine%g" % z, "MeshInstance3D", "Shell/Hazard", {"transform": xf((0, 0.012, z)), "mesh": 'SubResource("%s")' % line, "material_override": MAT("paint_yellow")})
seam = sub("PlaneMesh", {"add_uv2": "true", "size": "Vector2(36, 0.03)"})
for z in range(-1, 26, 4):
    node("FloorSeam%d" % z, "MeshInstance3D", "Shell", {"transform": xf((0, 0.011, z)), "mesh": 'SubResource("%s")' % seam, "material_override": MAT("seam")})
seam2 = sub("PlaneMesh", {"add_uv2": "true", "size": "Vector2(0.03, 34)"})
for x in range(-16, 17, 4):
    node("FloorSeamX%d" % x, "MeshInstance3D", "Shell", {"transform": xf((x, 0.011, 11)), "mesh": 'SubResource("%s")' % seam2, "material_override": MAT("seam")})
# catwalks along both walls at mid height
for side, nm in ((-1, "Left"), (1, "Right")):
    box("Catwalk" + nm, (5.0, 0.25, 26), (side * 14.5, CW, 7), "tread")
    box("CatwalkLip" + nm, (0.15, 0.45, 26), (side * 12.0, CW - 0.1, 7), "gunmetal")
    for h in (0.55, 1.1):
        box("CatwalkRail%s%g" % (nm, h), (0.06, 0.06, 26), (side * 12.05, CW + h, 7), "rail")
    for k in range(14):
        box("CatwalkPost%s%d" % (nm, k), (0.07, 1.1, 0.07), (side * 12.05, CW + 0.55, -5.5 + k * 2.0), "rail")
    for k in range(4):
        box("CatwalkStrut%s%d" % (nm, k), (0.35, CW, 0.35), (side * 12.3, CW / 2, -3 + k * 7.0), "gunmetal")
    for k in range(2):
        z = 2.0 + k * 7.0
        box("Strip%s%d" % (nm, k), (1.6, 0.06, 0.3), (side * 14.0, CW - 0.2, z), "strip_glow")
        node("Cool%s%d" % (nm, k), "OmniLight3D", "Lights", {"transform": xf((side * 14.0, CW - 0.6, z)), "light_color": "Color(0.78, 0.86, 1, 1)", "light_energy": "1.4", "omni_range": "5.5", "omni_attenuation": "1.6", "light_bake_mode": "2"}, groups=["secondary_light"])
# staircase on the left: from the catwalk down toward the left console bank
STEPS = 13; RUN = 0.42; X0 = -11.6
for k in range(STEPS):
    h = CW - (k + 1) * CW / STEPS
    box("Step%d" % k, (RUN, 0.08, 1.4), (X0 + RUN * k + RUN / 2, h + CW / STEPS - 0.04, 2.6), "gunmetal")
run = math.hypot(RUN * STEPS, CW); slope = math.degrees(math.atan2(CW, RUN * STEPS))
for zz in (1.9, 3.3):
    box("Stringer%g" % zz, (run, 0.28, 0.1), (X0 + RUN * STEPS / 2, CW / 2, zz), "gunmetal", rot_z=-slope)
    box("StairRail%g" % zz, (run, 0.05, 0.05), (X0 + RUN * STEPS / 2, CW / 2 + 1.0, zz), "rail", rot_z=-slope)
# blast door: a steel door in the left wall at floor level, under the catwalk, facing the camera
box("DoorBay", (8.4, CW, 0.6), (-13.2, CW / 2, 0.4), "concrete_dark")
kit("DoorFrame", "Door_Frame_SquareTall", (-13.6, 0, 0.75), 0, (0.72, 0.68, 1))
kit("DoorA", "Door_DarkMetal", (-13.6, 0, 0.72), 0, (0.72, 0.68, 1))
kit("DoorB", "Door_DarkMetal", (-12.08, 0, 0.72), 0, (0.72, 0.68, 1))
box("DoorLamp", (1.2, 0.08, 0.15), (-13.6, 3.75, 0.85), "strip_glow")
node("DoorLight", "OmniLight3D", "Lights", {"transform": xf((-13.6, 3.4, 1.6)), "light_color": "Color(0.8, 0.88, 1, 1)", "light_energy": "0.8", "omni_range": "4.5", "omni_attenuation": "1.6", "light_bake_mode": "2"}, groups=["secondary_light"])
# console banks at the Ring's base: grey steel cabinets with dark screens
for side, nm in ((-1, "Left"), (1, "Right")):
    cx = side * 6.9
    box("ConsoleBody" + nm, (4.8, 1.9, 1.0), (cx, 0.95, 1.6), "cabinet")
    for k in range(3):
        x = cx + (k - 1) * 1.5
        box("Screen%s%d" % (nm, k), (1.1, 0.55, 0.04), (x, 1.45, 2.12), "screen")
        box("Vent%s%d" % (nm, k), (1.1, 0.5, 0.03), (x, 0.55, 2.12), "seam")
# hanging lamps: two high, two low, visible below the top bar
LAMPS = [(-6.5, 10.0, 2.0), (6.5, 10.0, 2.0), (-4.1, 7.0, 6.0), (4.1, 7.0, 6.0)]
shade = sub("CylinderMesh", {"add_uv2": "true", "top_radius": "0.12", "bottom_radius": "0.55", "height": "0.45", "radial_segments": "16"})
bulb = sub("SphereMesh", {"radius": "0.2", "height": "0.24"})
for i, (x, y, z) in enumerate(LAMPS):
    cable = sub("CylinderMesh", {"add_uv2": "true", "top_radius": "0.015", "bottom_radius": "0.015", "height": "%g" % (14.4 - y)})
    node("Shade%d" % i, "MeshInstance3D", "Lights", {"transform": xf((x, y, z)), "mesh": 'SubResource("%s")' % shade, "material_override": MAT("gunmetal")})
    node("Bulb%d" % i, "MeshInstance3D", "Lights", {"transform": xf((x, y - 0.22, z)), "mesh": 'SubResource("%s")' % bulb, "material_override": MAT("lamp_glow")})
    node("Cable%d" % i, "MeshInstance3D", "Lights", {"transform": xf((x, (14.4 + y) / 2, z)), "mesh": 'SubResource("%s")' % cable, "material_override": MAT("gunmetal")})
    node("Sodium%d" % i, "SpotLight3D", "Lights", {"transform": xf((x, y - 0.35, z), rot_x=-90), "light_color": "Color(1, 0.7, 0.4, 1)", "light_energy": "22.0", "spot_range": "%g" % (y + 4), "spot_angle": "36.0", "spot_attenuation": "0.7", "spot_angle_attenuation": "1.3", "shadow_enabled": "true", "light_bake_mode": "2"})
node("RingWash", "SpotLight3D", "Lights", {"transform": xf((0, 11.0, 9), rot_x=-28), "light_color": "Color(0.95, 0.88, 0.78, 1)", "light_energy": "9.0", "spot_range": "22", "spot_angle": "22", "spot_attenuation": "1.0", "shadow_enabled": "true", "light_bake_mode": "2"})
probe = {"transform": xf((0, 4, 8)), "size": "Vector3(34, 10, 26)", "update_mode": "0", "intensity": "0.6", "interior": "true", "box_projection": "true", "ambient_mode": "0"}
node("FloorProbe", "ReflectionProbe", "Lights", probe)
for i, (x, y, z) in enumerate([(-9, 9, 0.5), (9, 9, 0.5), (-13, 2.5, 6), (13, 2.5, 6)]):
    node("Wash%d" % i, "OmniLight3D", "Lights", {"transform": xf((x, y, z)), "light_color": "Color(0.95, 0.78, 0.58, 1)", "light_energy": "0.9", "omni_range": "9.0", "omni_attenuation": "1.8", "light_bake_mode": "2"}, groups=["secondary_light"])
lm = {"quality": "2", "bounces": "3", "use_denoiser": "true", "directional": "false", "interior": "true", "environment_mode": "0", "texel_scale": "1.0"}
node("LightmapGI", "LightmapGI", ".", lm)
# the Ring itself is built in code (src/scenes/stations/ring/ring_3d.gd, M5-03)
for i in range(8):
    a = math.radians(i * 45)
    marker("clamp_%d" % i, (((R_IN + R_OUT) / 2) * math.sin(a), RING_Y + ((R_IN + R_OUT) / 2) * math.cos(a), 0.1))
# markers
marker("ring_inner", (0, RING_Y, -0.2), R_IN)
marker("ring_outer", (0, RING_Y, -0.2), R_OUT)
marker("door_left", (-13.6, 0, 1.3))
marker("rail", (4, 0, 8))
marker("console_left", (-6.9, 1.9, 1.6))
marker("console_right", (6.9, 1.9, 1.6))
path("ramp", [(0, PED, 1.1), (0, 0, 8.1)])
path("crossing", [(-10, 0, 9.5), (10, 0, 9.5)])

head = '[gd_scene load_steps=%d format=3]\n\n' % (len(ext) + len(subs) + 2)
head += '[ext_resource type="Script" path="res://src/scenes/stations/gate_hall.gd" id="script"]\n'
head += "".join('[ext_resource type="%s" path="%s" id="%s"]\n' % e for e in ext) + "\n"
root = '[node name="GateHall" type="Node3D"]\nscript = ExtResource("script")\n\n'
open(OUT, "w").write(head + "\n".join(subs) + "\n" + root + "\n".join(nodes))
print("nodes", len(nodes))
