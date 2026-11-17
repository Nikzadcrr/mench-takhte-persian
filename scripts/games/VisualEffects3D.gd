class_name VisualEffects3D
extends RefCounted

## Balanced, crisp museum-grade Persian Lounge lighting, reflections, velvet tabletop,
## PBR normal/roughness upgrades, subtle dust motes, and action particle bursts.


static func setup_lounge_environment(world: Node3D) -> void:
	# 1. Warm Candlelit Persian Lounge Reflection Sky (balanced so metals gleam without overexposing ivory!)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.14, 0.09, 0.065)
	sky_mat.sky_horizon_color = Color(0.32, 0.21, 0.13)
	sky_mat.ground_bottom_color = Color(0.06, 0.035, 0.025)
	sky_mat.ground_horizon_color = Color(0.20, 0.12, 0.07)
	sky_mat.sun_angle_max = 28.0
	sky_mat.energy_multiplier = 0.85

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.038, 0.028)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.96
	env.ssao_enabled = true
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.45 # Only true emissive rings & sparks bloom — NEVER the board!

	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# 2. Primary Warm Studio Overhead Key Light (crisp shadows, zero whiteout)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.86)
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.rotation_degrees = Vector3(-56, 30, 0)
	world.add_child(key)

	# 3. Subtle Cool Rim Light for 3D depth on pawns & wood edges
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.72, 0.84, 1.0)
	rim.light_energy = 0.32
	rim.rotation_degrees = Vector3(-34, -148, 0)
	world.add_child(rim)

	# 4. Soft Warm Accent OmniLight (gentle golden sheen on metallic gold trim)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.80, 0.48)
	lantern.light_energy = 0.65
	lantern.omni_range = 24.0
	lantern.omni_attenuation = 1.5
	lantern.position = Vector3(-3.5, 9.0, 4.5)
	world.add_child(lantern)

	# 5. Royal Persian Damask Carpet Tabletop
	var table := MeshInstance3D.new()
	var tp := PlaneMesh.new()
	tp.size = Vector2(72, 72)
	table.mesh = tp
	table.position = Vector3(0, -0.60, 0)
	var t_mat := StandardMaterial3D.new()
	if ResourceLoader.exists("res://assets/textures/table_carpet.png"):
		t_mat.albedo_texture = load("res://assets/textures/table_carpet.png")
		t_mat.uv1_scale = Vector3(7.0, 7.0, 1.0)
	else:
		t_mat.albedo_color = Color(0.14, 0.05, 0.06)
	t_mat.roughness = 0.90
	table.material_override = t_mat
	world.add_child(table)

	# 6. Delicate Ambient Golden Dust Motes
	var motes := GPUParticles3D.new()
	motes.amount = 20
	motes.lifetime = 6.0
	motes.position = Vector3(0, 3.0, 0)
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(7.5, 2.0, 7.5)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 30.0
	pmat.gravity = Vector3(0, 0.04, 0)
	pmat.initial_velocity_min = 0.10
	pmat.initial_velocity_max = 0.26
	pmat.scale_min = 0.025
	pmat.scale_max = 0.055
	pmat.color = Color(1.0, 0.86, 0.48, 0.45)
	motes.process_material = pmat

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.88, 0.52)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.82, 0.38)
	smat.emission_energy_multiplier = 1.8
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = smat
	motes.draw_pass_1 = sphere
	world.add_child(motes)


static func enhance_walnut_frame_pbr(frame_root: Node) -> void:
	var n_tex: Texture2D = load("res://assets/textures/walnut_normal.png") if ResourceLoader.exists("res://assets/textures/walnut_normal.png") else null
	var r_tex: Texture2D = load("res://assets/textures/walnut_roughness.png") if ResourceLoader.exists("res://assets/textures/walnut_roughness.png") else null
	_enhance_rec(frame_root, n_tex, r_tex)


static func _enhance_rec(node: Node, n_tex: Texture2D, r_tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var lname := mi.name.to_lower()
		var mesh := mi.mesh
		if mesh and mesh.get_surface_count() > 0:
			var orig := mesh.surface_get_material(0)
			if orig is StandardMaterial3D:
				var mat := (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
				if "brass" in lname or "hinge" in lname or "clasp" in lname or "corner" in lname:
					mat.metallic = 0.88
					mat.roughness = 0.25
					mat.clearcoat_enabled = true
					mat.clearcoat = 0.25
				elif not ("velvet" in lname):
					if n_tex:
						mat.normal_enabled = true
						mat.normal_texture = n_tex
						mat.normal_scale = 0.55
					if r_tex:
						mat.roughness_texture = r_tex
					mat.roughness = 0.36
					mat.clearcoat_enabled = true
					mat.clearcoat = 0.28
				mi.material_override = mat
	for c in node.get_children():
		_enhance_rec(c, n_tex, r_tex)


static func apply_body_material_preserve_gold(root: Node, body_mat: Material) -> void:
	if root is MeshInstance3D:
		var lname := root.name.to_lower()
		if not ("gold" in lname or "torus" in lname or "finial" in lname or "ring" in lname):
			(root as MeshInstance3D).material_override = body_mat
	for c in root.get_children():
		apply_body_material_preserve_gold(c, body_mat)


static func spawn_spark_burst(world: Node3D, pos: Vector3, col: Color = Color(1.0, 0.85, 0.32), count: int = 24) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.position = pos + Vector3(0, 0.35, 0)
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.72

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 65.0
	pmat.gravity = Vector3(0, -6.5, 0)
	pmat.initial_velocity_min = 2.4
	pmat.initial_velocity_max = 5.2
	pmat.scale_min = 0.055
	pmat.scale_max = 0.11
	pmat.color = col
	p.process_material = pmat

	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.draw_pass_1 = sm

	world.add_child(p)
	p.emitting = true
	world.get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
