class_name Projectile
extends Node3D

const HIT_DISTANCE := 0.45

var kind: int = 0
var target: Node3D = null
var speed: float = 14.0
var damage: int = 5
var aoe_radius: float = 0.0
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var chain_count: int = 0
var chain_range: float = 0.0
var poison_dps: float = 0.0
var poison_duration: float = 0.0
var color: Color = Color(0.4, 0.7, 1.0)

var _hit_done: bool = false
var _mesh_node: Node3D = null
var _spin_axis: Vector3 = Vector3.UP
var _spin_speed: float = 0.0
var _anim_time: float = 0.0
var _orbit_nodes: Array[Node3D] = []
var _orbit_radius: float = 0.32
var _orbit_speed: float = 6.0

func _ready() -> void:
	_build_visual()
	_build_trail()

func _build_visual() -> void:
	match kind:
		Tower.Kind.MAGIC:
			_mesh_node = _make_sphere(0.2, color, 2.5)
		Tower.Kind.ICE:
			_mesh_node = _make_box(Vector3(0.32, 0.32, 0.32), color, 1.8)
			_mesh_node.rotation = Vector3(0.4, 0.0, 0.4)
			_spin_axis = Vector3(0.3, 1.0, 0.0).normalized()
			_spin_speed = 6.0
		Tower.Kind.CANNON:
			_mesh_node = _make_sphere(0.28, Color(0.15, 0.12, 0.1), 0.3)
		Tower.Kind.LIGHTNING:
			_mesh_node = _make_capsule(0.08, 0.6, color, 3.5)
			_mesh_node.rotation.x = PI * 0.5
		Tower.Kind.POISON:
			_mesh_node = _make_poison_blob()
		_:
			_mesh_node = _make_sphere(0.2, color, 2.5)
	add_child(_mesh_node)

func _make_sphere(r: float, c: Color, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2
	mi.mesh = sph
	mi.material_override = _make_glow_mat(c, emission)
	return mi

func _make_box(size: Vector3, c: Color, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = size
	mi.mesh = bx
	mi.material_override = _make_glow_mat(c, emission)
	return mi

func _make_capsule(r: float, h: float, c: Color, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cp := CapsuleMesh.new()
	cp.radius = r
	cp.height = h
	mi.mesh = cp
	mi.material_override = _make_glow_mat(c, emission)
	return mi

func _make_poison_blob() -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	core.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material_override = mat
	root.add_child(core)

	var aura := GPUParticles3D.new()
	aura.amount = 28
	aura.lifetime = 0.6
	aura.emitting = true
	aura.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.1
	pm.scale_max = 0.22
	pm.color = Color(color.r, color.g, color.b, 0.45)
	aura.process_material = pm

	var amesh := SphereMesh.new()
	amesh.radius = 0.08
	amesh.height = 0.16
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	amat.emission_enabled = true
	amat.emission = color
	amat.emission_energy_multiplier = 0.9
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amesh.material = amat
	aura.draw_pass_1 = amesh
	root.add_child(aura)

	var orb_colors: Array[Color] = [Color(0.8, 1.0, 0.4), Color(0.5, 0.9, 0.3)]
	for i in range(orb_colors.size()):
		var orb: MeshInstance3D = _make_sphere(0.07, orb_colors[i], 3.0)
		root.add_child(orb)
		_orbit_nodes.append(orb)
	_orbit_radius = 0.32
	_orbit_speed = 5.0
	return root

func _make_glow_mat(c: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = emission
	return mat

func _build_trail() -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = false
	particles.emitting = true
	particles.local_coords = false
	var mesh := SphereMesh.new()
	var pm := ParticleProcessMaterial.new()
	pm.spread = 25.0
	pm.gravity = Vector3.ZERO
	var trail_color: Color = color

	match kind:
		Tower.Kind.MAGIC:
			particles.amount = 16
			particles.lifetime = 0.35
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.5
			pm.scale_min = 0.05
			pm.scale_max = 0.12
			mesh.radius = 0.05
			mesh.height = 0.1
		Tower.Kind.ICE:
			particles.amount = 14
			particles.lifetime = 0.4
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.8
			pm.scale_min = 0.04
			pm.scale_max = 0.1
			trail_color = Color(0.85, 0.95, 1.0)
			mesh.radius = 0.05
			mesh.height = 0.1
		Tower.Kind.CANNON:
			particles.amount = 18
			particles.lifetime = 0.5
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3(0, 0.5, 0)
			pm.scale_min = 0.1
			pm.scale_max = 0.2
			trail_color = Color(0.3, 0.27, 0.25, 0.7)
			mesh.radius = 0.08
			mesh.height = 0.16
		Tower.Kind.LIGHTNING:
			particles.amount = 22
			particles.lifetime = 0.25
			pm.initial_velocity_min = 0.5
			pm.initial_velocity_max = 1.5
			pm.spread = 60.0
			pm.scale_min = 0.04
			pm.scale_max = 0.1
			mesh.radius = 0.04
			mesh.height = 0.08
		Tower.Kind.POISON:
			particles.amount = 24
			particles.lifetime = 0.8
			pm.spread = 180.0
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3(0, 0.4, 0)
			pm.scale_min = 0.1
			pm.scale_max = 0.25
			trail_color = Color(color.r, color.g, color.b, 0.5)
			mesh.radius = 0.08
			mesh.height = 0.16
		_:
			particles.amount = 16
			particles.lifetime = 0.35
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.5
			pm.scale_min = 0.05
			pm.scale_max = 0.12
			mesh.radius = 0.05
			mesh.height = 0.1

	pm.color = trail_color
	particles.process_material = pm

	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = trail_color
	tmat.emission_enabled = true
	tmat.emission = trail_color
	tmat.emission_energy_multiplier = 1.5
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = tmat
	particles.draw_pass_1 = mesh
	add_child(particles)

func _process(delta: float) -> void:
	if _hit_done:
		return
	_anim_time += delta
	if _spin_speed > 0.0 and _mesh_node:
		_mesh_node.rotate(_spin_axis, _spin_speed * delta)
	if kind == Tower.Kind.LIGHTNING and _mesh_node:
		var s: float = 1.0 + sin(_anim_time * 40.0) * 0.25
		_mesh_node.scale = Vector3(s, 1.0, s)
	for i in range(_orbit_nodes.size()):
		var orb: Node3D = _orbit_nodes[i]
		var angle: float = _anim_time * _orbit_speed + float(i) * PI
		var bob: float = sin(_anim_time * 4.0 + float(i)) * 0.08
		orb.position = Vector3(cos(angle) * _orbit_radius, bob, sin(angle) * _orbit_radius)

func _physics_process(delta: float) -> void:
	if _hit_done:
		return
	if not is_instance_valid(target):
		queue_free()
		return
	var target_pos: Vector3 = target.global_position + Vector3(0, 0.7, 0)
	var to_target: Vector3 = target_pos - global_position
	var dist: float = to_target.length()
	if dist < HIT_DISTANCE:
		_hit()
		return
	global_position += to_target.normalized() * speed * delta
	if kind == Tower.Kind.LIGHTNING:
		look_at(target_pos, Vector3.UP)

func _hit() -> void:
	_hit_done = true
	var impact_pos := global_position
	if aoe_radius > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and e.global_position.distance_to(impact_pos) <= aoe_radius:
				_apply_to(e, impact_pos)
		Effects.spawn_burst(get_tree().current_scene, impact_pos, color, aoe_radius * 0.7)
	else:
		if target is Enemy:
			_apply_to(target, impact_pos)
			if chain_count > 0:
				_chain_hit(impact_pos, [target], chain_count)
	queue_free()

func _apply_to(enemy: Enemy, _pos: Vector3) -> void:
	if slow_amount > 0.0:
		enemy.apply_slow(slow_amount, slow_duration)
	if poison_dps > 0.0:
		enemy.apply_poison(poison_dps, poison_duration)
	enemy.take_damage(damage)

func _chain_hit(from_pos: Vector3, already_hit: Array, hops_left: int) -> void:
	if hops_left <= 0:
		return
	var nearest: Enemy = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in already_hit:
			continue
		if e is Enemy:
			var d: float = e.global_position.distance_to(from_pos)
			if d <= chain_range and d < nearest_dist:
				nearest_dist = d
				nearest = e
	if nearest == null:
		return
	var hit_pos: Vector3 = nearest.global_position + Vector3(0, 0.7, 0)
	_apply_to(nearest, hit_pos)
	Effects.spawn_burst(get_tree().current_scene, hit_pos, color, 0.5)
	already_hit.append(nearest)
	_chain_hit(hit_pos, already_hit, hops_left - 1)
