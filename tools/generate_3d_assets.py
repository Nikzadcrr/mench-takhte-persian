#!/usr/bin/env python3
"""
Upgraded Blender 5.2.x headless script to generate luxury multi-material
3D GLB assets for Portrait Mobile Persian Board Games (Mench & Takhte Nard).
"""

import math
import os
import bpy
import bmesh
from mathutils import Vector

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(BASE_DIR, "assets", "models")
TEX_DIR = os.path.join(BASE_DIR, "assets", "textures")
os.makedirs(MODEL_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, color=(0.8, 0.8, 0.8, 1.0), roughness=0.30, metallic=0.0, tex_path=None):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if tex_path and os.path.exists(tex_path):
        tex_node = nt.nodes.new("ShaderNodeTexImage")
        tex_node.image = bpy.data.images.load(tex_path)
        nt.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = color
    return mat


def set_smooth(obj):
    if obj.type != "MESH":
        return
    for p in obj.data.polygons:
        p.use_smooth = True


def export_glb(filename):
    path = os.path.join(MODEL_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
    )
    print(f"Exported {path}")


def create_revolved_mesh(name, profile_rz, segments=48, mat=None):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for (r, z) in profile_rz]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]

    geom = list(bm.verts) + edges
    bmesh.ops.spin(
        bm,
        geom=geom,
        cent=(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        angle=math.tau,
        steps=segments,
        use_merge=True,
    )
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    set_smooth(obj)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_torus_ring(name, z, major_r, minor_r, mat):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=40,
        minor_segments=14,
        major_radius=major_r,
        minor_radius=minor_r,
        location=(0, 0, z),
    )
    obj = bpy.context.active_object
    obj.name = name
    set_smooth(obj)
    obj.data.materials.append(mat)
    return obj


def build_ludo_pawn():
    """Royal sculpted Ludo pawn with separate gold-trim rings (PawnGoldTrim)."""
    clear_scene()
    body_mat = make_material("PawnBodyMat", color=(0.86, 0.86, 0.86, 1.0), roughness=0.18, metallic=0.10)
    gold_mat = make_material("RoyalGoldMat", color=(0.94, 0.76, 0.30, 1.0), roughness=0.20, metallic=0.92)

    profile = [
        (0.0, 0.0),
        (0.37, 0.0),
        (0.38, 0.045),
        (0.34, 0.12),
        (0.28, 0.17),
        (0.25, 0.24),
        (0.20, 0.38),
        (0.16, 0.54),
        (0.15, 0.65),
        (0.22, 0.70),
        (0.22, 0.75),
        (0.145, 0.79),
    ]
    head_cz = 1.00
    head_r = 0.24
    for i in range(13):
        ang = math.radians(-62 + i * (152.0 / 12.0))
        r = max(0.0, math.cos(ang) * head_r)
        z = head_cz + math.sin(ang) * head_r
        profile.append((r, z))
    profile.append((0.0, head_cz + head_r))

    create_revolved_mesh("PawnBody", profile, segments=48, mat=body_mat)

    # Ornate metallic gold trim rings (preserved when Godot tints PawnBody!)
    add_torus_ring("PawnGoldTrim_Base", 0.09, 0.355, 0.022, gold_mat)
    add_torus_ring("PawnGoldTrim_Collar", 0.725, 0.225, 0.026, gold_mat)

    # Tiny royal gold finial knob on top of crown
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.055, location=(0, 0, head_cz + head_r + 0.02))
    finial = bpy.context.active_object
    finial.name = "PawnGoldTrim_Finial"
    set_smooth(finial)
    finial.data.materials.append(gold_mat)

    export_glb("ludo_pawn.glb")


def build_backgammon_checker():
    """Turned luxury Persian checker with recessed metallic gold inlay ring."""
    clear_scene()
    body_mat = make_material("CheckerBodyMat", color=(0.92, 0.88, 0.80, 1.0), roughness=0.22, metallic=0.06)
    gold_mat = make_material("CheckerGoldMat", color=(0.92, 0.74, 0.28, 1.0), roughness=0.22, metallic=0.90)

    # Sized cleanly for portrait 12.4 x 13.6 board (radius ~0.41, height ~0.22)
    profile = [
        (0.0, 0.0),
        (0.39, 0.0),
        (0.415, 0.03),
        (0.42, 0.11),
        (0.415, 0.185),
        (0.385, 0.22),
        (0.33, 0.22),
        (0.30, 0.195),
        (0.24, 0.190),
        (0.18, 0.175),
        (0.09, 0.165),
        (0.0, 0.162),
    ]
    create_revolved_mesh("CheckerBody", profile, segments=48, mat=body_mat)
    add_torus_ring("CheckerGoldRing", 0.205, 0.315, 0.016, gold_mat)
    export_glb("backgammon_checker.glb")


def build_dice():
    """Luxury rounded bone-ivory die with gold-rimmed crimson 1-pip & dark pips."""
    clear_scene()
    body_mat = make_material("DiceIvory", color=(0.97, 0.94, 0.86, 1.0), roughness=0.16, metallic=0.04)
    pip_mat = make_material("DicePip", color=(0.08, 0.05, 0.04, 1.0), roughness=0.24, metallic=0.35)
    pip_red_mat = make_material("DicePipCrimson", color=(0.74, 0.10, 0.14, 1.0), roughness=0.20, metallic=0.20)
    gold_mat = make_material("DiceGold", color=(0.94, 0.76, 0.30, 1.0), roughness=0.20, metallic=0.92)

    bpy.ops.mesh.primitive_cube_add(size=0.74, location=(0, 0, 0))
    cube = bpy.context.active_object
    cube.name = "DiceBody"
    bev = cube.modifiers.new(name="Bevel", type="BEVEL")
    bev.width = 0.095
    bev.segments = 5
    bev.limit_method = "NONE"
    bpy.ops.object.modifier_apply(modifier="Bevel")
    set_smooth(cube)
    cube.data.materials.append(body_mat)

    h = 0.366
    d = 0.168
    pip_r = 0.058

    face_layouts = {
        1: [(0, 0)],
        2: [(-d, -d), (d, d)],
        3: [(-d, -d), (0, 0), (d, d)],
        4: [(-d, -d), (-d, d), (d, -d), (d, d)],
        5: [(-d, -d), (-d, d), (0, 0), (d, -d), (d, d)],
        6: [(-d, -d), (-d, 0), (-d, d), (d, -d), (d, 0), (d, d)],
    }

    faces = [
        (1, Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
        (6, Vector((0, 0, -1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
        (2, Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
        (5, Vector((0, 1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
        (3, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
        (4, Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
    ]

    for val, n, u, v in faces:
        for idx, (pu, pv) in enumerate(face_layouts[val]):
            pos = n * h + u * pu + v * pv
            r_use = pip_r * 1.28 if val == 1 else pip_r
            bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=r_use, location=pos)
            pip = bpy.context.active_object
            pip.name = f"Pip_{val}_{idx}"
            rot_quat = Vector((0, 0, 1)).rotation_difference(n)
            pip.rotation_mode = "QUATERNION"
            pip.rotation_quaternion = rot_quat
            pip.scale = (1.0, 1.0, 0.32)
            set_smooth(pip)
            pip.data.materials.append(pip_red_mat if val == 1 else pip_mat)

            if val == 1:
                # Golden halo around the royal 1-pip
                add_torus_ring("Pip1_GoldRing", h + 0.004, r_use * 1.12, 0.013, gold_mat)

    export_glb("dice.glb")


def add_box(name, loc, scale, mat, bevel_width=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if bevel_width > 0:
        bev = obj.modifiers.new(name="Bevel", type="BEVEL")
        bev.width = bevel_width
        bev.segments = 3
        bpy.ops.object.modifier_apply(modifier="Bevel")
    set_smooth(obj)
    obj.data.materials.append(mat)
    return obj


def build_ludo_board_frame():
    """Stepped Persian walnut cabinet + brass inlay trim for 15x15 Ludo board."""
    clear_scene()
    walnut = make_material(
        "WalnutFrame",
        color=(0.24, 0.12, 0.06, 1.0),
        roughness=0.28,
        metallic=0.04,
        tex_path=os.path.join(TEX_DIR, "walnut_wood.png"),
    )
    brass = make_material("RoyalBrass", color=(0.90, 0.72, 0.30, 1.0), roughness=0.22, metallic=0.90)

    # Tiered wooden pedestal base
    add_box("BoardPlinth", (0, 0, -0.44), (17.1, 17.1, 0.36), walnut, bevel_width=0.08)
    add_box("BoardBase", (0, 0, -0.18), (16.5, 16.5, 0.36), walnut, bevel_width=0.05)

    rim_w = 0.76
    rim_h = 0.38
    offset = 7.5 + rim_w * 0.5
    add_box("RimNorth", (0, offset, rim_h * 0.36), (15.0 + rim_w * 2, rim_w, rim_h), walnut, bevel_width=0.06)
    add_box("RimSouth", (0, -offset, rim_h * 0.36), (15.0 + rim_w * 2, rim_w, rim_h), walnut, bevel_width=0.06)
    add_box("RimEast", (offset, 0, rim_h * 0.36), (rim_w, 15.0, rim_h), walnut, bevel_width=0.06)
    add_box("RimWest", (-offset, 0, rim_h * 0.36), (rim_w, 15.0, rim_h), walnut, bevel_width=0.06)

    # Gleaming inner brass trim strips right along the playing field
    t_off = 7.54
    add_box("BrassTrimN", (0, t_off, 0.08), (15.16, 0.08, 0.14), brass, bevel_width=0.015)
    add_box("BrassTrimS", (0, -t_off, 0.08), (15.16, 0.08, 0.14), brass, bevel_width=0.015)
    add_box("BrassTrimE", (t_off, 0, 0.08), (0.08, 15.08, 0.14), brass, bevel_width=0.015)
    add_box("BrassTrimW", (-t_off, 0, 0.08), (0.08, 15.08, 0.14), brass, bevel_width=0.015)

    # Ornate Brass Corner Brackets
    c_off = 7.5 + rim_w * 0.52
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(f"BrassCorner_{sx}_{sy}", (sx * c_off, sy * c_off, rim_h * 0.44), (0.90, 0.90, rim_h + 0.06), brass, bevel_width=0.05)

    export_glb("ludo_board_frame.glb")


def build_backgammon_board_frame():
    """
    Portrait-proportioned luxury walnut cabinet for the 12.4 x 13.6 Backgammon board!
    Includes stepped base, brass trim, hinges, velvet-lined right bear-off trays.
    """
    clear_scene()
    walnut = make_material(
        "WalnutBox",
        color=(0.22, 0.11, 0.055, 1.0),
        roughness=0.28,
        metallic=0.04,
        tex_path=os.path.join(TEX_DIR, "walnut_wood.png"),
    )
    walnut_dark = make_material("WalnutDark", color=(0.13, 0.065, 0.03, 1.0), roughness=0.34, metallic=0.04)
    velvet = make_material("TrayVelvet", color=(0.24, 0.06, 0.08, 1.0), roughness=0.88, metallic=0.0)
    brass = make_material("RoyalBrass", color=(0.90, 0.72, 0.30, 1.0), roughness=0.22, metallic=0.90)

    # Playing bed spans X: -6.2..+6.2 (12.4), Y: -6.8..+6.8 (13.6) at Z=0
    bw, bh = 12.4, 13.6
    wall = 0.58
    wall_h = 0.54
    tray_extra = 1.32
    total_w = bw + wall * 2 + tray_extra
    shift_x = tray_extra * 0.5

    # Stepped Plinth + Base
    add_box("CabinetPlinth", (shift_x, 0, -0.44), (total_w + 0.5, bh + wall * 2 + 0.5, 0.34), walnut_dark, bevel_width=0.07)
    add_box("CabinetBase", (shift_x, 0, -0.18), (total_w, bh + wall * 2, 0.36), walnut, bevel_width=0.05)

    # Velvet lining inside the right bear-off tray
    add_box("TrayVelvetBed", (bw * 0.5 + 0.24 + (tray_extra - 0.24) * 0.5, 0, 0.01), (tray_extra - 0.26, bh - 0.1, 0.04), velvet, bevel_width=0.0)

    # Outer Walls
    add_box("WallTop", (shift_x, bh * 0.5 + wall * 0.5, wall_h * 0.42), (total_w, wall, wall_h), walnut, bevel_width=0.05)
    add_box("WallBottom", (shift_x, -(bh * 0.5 + wall * 0.5), wall_h * 0.42), (total_w, wall, wall_h), walnut, bevel_width=0.05)
    add_box("WallLeft", (-(bw * 0.5 + wall * 0.5), 0, wall_h * 0.42), (wall, bh, wall_h), walnut, bevel_width=0.05)
    add_box("WallRightInner", (bw * 0.5 + 0.14, 0, wall_h * 0.36), (0.28, bh, wall_h * 0.85), walnut_dark, bevel_width=0.03)
    add_box("WallRightOuter", (bw * 0.5 + tray_extra + wall * 0.5, 0, wall_h * 0.42), (wall, bh, wall_h), walnut, bevel_width=0.05)
    add_box("TrayDivider", (bw * 0.5 + 0.28 + (tray_extra - 0.28) * 0.5, 0, wall_h * 0.32), (tray_extra - 0.28, 0.26, wall_h * 0.74), walnut_dark, bevel_width=0.03)

    # Central raised bar divider (matches 116px bar -> ~0.80 world units)
    add_box("CenterBar", (0, 0, 0.14), (0.80, bh, 0.26), walnut_dark, bevel_width=0.04)
    add_box("BarBrassStrip", (0, 0, 0.275), (0.08, bh - 0.4, 0.03), brass, bevel_width=0.008)

    # Brass Hinges & Corner Caps
    add_box("HingeTop", (0, bh * 0.5 + wall * 0.5, wall_h * 0.48), (1.05, wall + 0.08, wall_h * 0.72), brass, bevel_width=0.02)
    add_box("HingeBottom", (0, -(bh * 0.5 + wall * 0.5), wall_h * 0.48), (1.05, wall + 0.08, wall_h * 0.72), brass, bevel_width=0.02)
    add_box("ClaspLeft", (-(bw * 0.5 + wall), 0, wall_h * 0.36), (0.14, 0.95, 0.32), brass, bevel_width=0.02)

    for sx in (-1, 1):
        cx = (bw * 0.5 + tray_extra + wall * 0.5) if sx > 0 else -(bw * 0.5 + wall * 0.5)
        for sy in (-1, 1):
            cy = sy * (bh * 0.5 + wall * 0.5)
            add_box(f"CornerCap_{sx}_{sy}", (cx, cy, wall_h * 0.48), (0.68, 0.68, wall_h + 0.04), brass, bevel_width=0.03)

    export_glb("backgammon_board_frame.glb")


if __name__ == "__main__":
    build_ludo_pawn()
    build_backgammon_checker()
    build_dice()
    build_ludo_board_frame()
    build_backgammon_board_frame()
    print("All upgraded multi-material 3D GLB assets built in Blender!")
