class_name Effects
extends Node

static func spawn_burst(parent: Node, pos: Vector3, color: Color, scale_factor: float = 1.0) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.position = pos

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0 * scale_factor
	process_mat.initial_velocity_max = 4.0 * scale_factor
	process_mat.gravity = Vector3(0, -3.0, 0)
	process_mat.scale_min = 0.15 * scale_factor
	process_mat.scale_max = 0.3 * scale_factor
	process_mat.color = color
	particles.process_material = process_mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.finished.connect(particles.queue_free)
