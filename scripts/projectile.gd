class_name Projectile
extends Node3D

const RADIUS := 0.2
const HIT_DISTANCE := 0.45

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

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = RADIUS
	sph.height = RADIUS * 2
	mesh.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mesh.material_override = mat
	add_child(mesh)

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
