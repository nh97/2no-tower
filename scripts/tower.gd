class_name Tower
extends StaticBody3D

enum Kind { MAGIC, ICE, CANNON, LIGHTNING, POISON }

const BASE_HEIGHT := 1.2
const BASE_RADIUS := 0.6
const ORB_OFFSET_Y := 1.8

const CONFIG := {
	Kind.MAGIC: {
		"cost": 50,
		"damage": 5,
		"range": 6.0,
		"interval": 0.6,
		"projectile_speed": 14.0,
		"aoe_radius": 0.0,
		"slow_amount": 0.0,
		"slow_duration": 0.0,
		"orb_color": Color(0.75, 0.45, 1.0),
		"base_color": Color(0.5, 0.5, 0.55),
		"orb_radius": 0.35,
		"label": "🪄 魔法",
		"model_path": "res://models/Gem_Pink.gltf",
		"model_scale": 1.3,
		"model_y_offset": 1.5,
	},
	Kind.ICE: {
		"cost": 70,
		"damage": 1,
		"range": 5.0,
		"interval": 0.4,
		"projectile_speed": 12.0,
		"aoe_radius": 0.0,
		"slow_amount": 0.45,
		"slow_duration": 0.5,
		"orb_color": Color(0.5, 0.85, 1.0),
		"base_color": Color(0.35, 0.55, 0.6),
		"orb_radius": 0.3,
		"label": "❄ 氷",
		"model_path": "res://models/Gem_Blue.gltf",
		"model_scale": 1.3,
		"model_y_offset": 1.7,
	},
	Kind.CANNON: {
		"cost": 100,
		"damage": 12,
		"range": 7.0,
		"interval": 1.4,
		"projectile_speed": 10.0,
		"aoe_radius": 1.8,
		"slow_amount": 0.0,
		"slow_duration": 0.0,
		"orb_color": Color(1.0, 0.55, 0.25),
		"base_color": Color(0.55, 0.4, 0.3),
		"orb_radius": 0.42,
		"label": "💥 大砲",
		"model_path": "res://models/Cannon.gltf",
		"model_scale": 0.7,
		"model_y_offset": 0.7,
	},
	Kind.LIGHTNING: {
		"cost": 110,
		"damage": 6,
		"range": 6.0,
		"interval": 0.8,
		"projectile_speed": 18.0,
		"aoe_radius": 0.0,
		"slow_amount": 0.0,
		"slow_duration": 0.0,
		"chain_count": 3,
		"chain_range": 3.0,
		"orb_color": Color(1.0, 0.95, 0.3),
		"base_color": Color(0.5, 0.45, 0.25),
		"orb_radius": 0.34,
		"label": "⚡ 雷",
		"model_path": "res://models/Thunder.gltf",
		"model_scale": 1.3,
		"model_y_offset": 1.4,
	},
	Kind.POISON: {
		"cost": 90,
		"damage": 2,
		"range": 5.0,
		"interval": 1.0,
		"projectile_speed": 12.0,
		"aoe_radius": 0.0,
		"slow_amount": 0.0,
		"slow_duration": 0.0,
		"poison_dps": 2.0,
		"poison_duration": 4.0,
		"orb_color": Color(0.45, 0.95, 0.35),
		"base_color": Color(0.35, 0.55, 0.3),
		"orb_radius": 0.36,
		"label": "☠ 毒",
		"model_path": "res://models/Skull.gltf",
		"model_scale": 1.2,
		"model_y_offset": 0.3,
	},
}

var kind: int = Kind.MAGIC
var build_cost: int = 0

var _range_area: Area3D
var _fire_timer: Timer
var _orb: MeshInstance3D
var _orb_time: float = 0.0
var _model_node: Node3D = null
var _anim_player: AnimationPlayer = null
var _fire_tween: Tween = null

func _ready() -> void:
	input_ray_pickable = false
	_build_visual()
	_build_range_area()
	_build_fire_timer()

func _process(delta: float) -> void:
	_orb_time += delta
	if _orb:
		_orb.position.y = ORB_OFFSET_Y + sin(_orb_time * 2.2) * 0.15

func _build_visual() -> void:
	var cfg: Dictionary = CONFIG[kind]
	var model_path: String = cfg.get("model_path", "")
	if model_path != "" and ResourceLoader.exists(model_path):
		var scene: Node = load(model_path).instantiate()
		scene.scale = Vector3.ONE * cfg.get("model_scale", 1.0)
		scene.position.y = cfg.get("model_y_offset", 0.0)
		add_child(scene)
		_model_node = scene
		var anim_player := scene.find_child("AnimationPlayer") as AnimationPlayer
		if anim_player:
			_anim_player = anim_player
	else:
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = BASE_RADIUS * 0.7
		cyl.bottom_radius = BASE_RADIUS
		cyl.height = BASE_HEIGHT
		base.mesh = cyl
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = cfg.base_color
		base_mat.roughness = 0.7
		base.material_override = base_mat
		base.position.y = BASE_HEIGHT * 0.5
		add_child(base)

		_orb = MeshInstance3D.new()
		var sph := SphereMesh.new()
		var orb_r: float = cfg.orb_radius
		sph.radius = orb_r
		sph.height = orb_r * 2
		_orb.mesh = sph
		var orb_mat := StandardMaterial3D.new()
		orb_mat.albedo_color = cfg.orb_color
		orb_mat.emission_enabled = true
		orb_mat.emission = cfg.orb_color
		orb_mat.emission_energy_multiplier = 1.4
		_orb.material_override = orb_mat
		_orb.position.y = ORB_OFFSET_Y
		_orb.name = "Orb"
		add_child(_orb)

	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = BASE_RADIUS
	cyl_shape.height = BASE_HEIGHT
	shape.shape = cyl_shape
	shape.position.y = BASE_HEIGHT * 0.5
	add_child(shape)

func _build_range_area() -> void:
	var cfg: Dictionary = CONFIG[kind]
	_range_area = Area3D.new()
	_range_area.name = "Range"
	_range_area.input_ray_pickable = false
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = cfg.range
	col.shape = sph
	col.position.y = 0.5
	_range_area.add_child(col)
	add_child(_range_area)

func _build_fire_timer() -> void:
	var cfg: Dictionary = CONFIG[kind]
	_fire_timer = Timer.new()
	_fire_timer.wait_time = cfg.interval
	_fire_timer.one_shot = false
	_fire_timer.timeout.connect(_try_fire)
	add_child(_fire_timer)
	_fire_timer.start()

func _try_fire() -> void:
	var target := _find_target()
	if target == null:
		return
	var cfg: Dictionary = CONFIG[kind]
	var proj := Projectile.new()
	proj.target = target
	proj.damage = cfg.damage
	proj.speed = cfg.projectile_speed
	proj.aoe_radius = cfg.aoe_radius
	proj.slow_amount = cfg.slow_amount
	proj.slow_duration = cfg.slow_duration
	proj.chain_count = cfg.get("chain_count", 0)
	proj.chain_range = cfg.get("chain_range", 0.0)
	proj.poison_dps = cfg.get("poison_dps", 0.0)
	proj.poison_duration = cfg.get("poison_duration", 0.0)
	proj.color = cfg.orb_color
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, ORB_OFFSET_Y, 0)
	AudioManager.play_sfx(_get_fire_sfx())
	_play_fire_animation()

func _get_fire_sfx() -> int:
	match kind:
		Kind.MAGIC: return AudioManager.SFX.TOWER_FIRE_MAGIC
		Kind.ICE: return AudioManager.SFX.TOWER_FIRE_ICE
		Kind.CANNON: return AudioManager.SFX.TOWER_FIRE_CANNON
		Kind.LIGHTNING: return AudioManager.SFX.TOWER_FIRE_LIGHTNING
		Kind.POISON: return AudioManager.SFX.TOWER_FIRE_POISON
	return AudioManager.SFX.TOWER_FIRE

func _play_fire_animation() -> void:
	if _model_node == null:
		return
	match kind:
		Kind.MAGIC, Kind.ICE:
			_scale_punch()
		Kind.CANNON:
			_rotation_kick()
		Kind.LIGHTNING:
			_vertical_bounce()
		Kind.POISON:
			_play_bite()

func _kill_fire_tween() -> void:
	if _fire_tween and _fire_tween.is_valid():
		_fire_tween.kill()

func _scale_punch() -> void:
	_kill_fire_tween()
	var base_scale: Vector3 = Vector3.ONE * float(CONFIG[kind].get("model_scale", 1.0))
	_model_node.scale = base_scale
	_fire_tween = create_tween()
	_fire_tween.tween_property(_model_node, "scale", base_scale * 1.15, 0.07)
	_fire_tween.tween_property(_model_node, "scale", base_scale, 0.10)

func _rotation_kick() -> void:
	_kill_fire_tween()
	_model_node.rotation.x = 0.0
	_fire_tween = create_tween()
	_fire_tween.tween_property(_model_node, "rotation:x", deg_to_rad(-15.0), 0.06)
	_fire_tween.tween_property(_model_node, "rotation:x", 0.0, 0.14)

func _vertical_bounce() -> void:
	_kill_fire_tween()
	var base_y: float = float(CONFIG[kind].get("model_y_offset", 0.0))
	_model_node.position.y = base_y
	_fire_tween = create_tween()
	_fire_tween.tween_property(_model_node, "position:y", base_y + 0.25, 0.08)
	_fire_tween.tween_property(_model_node, "position:y", base_y, 0.12)

func _play_bite() -> void:
	if _anim_player == null or not _anim_player.has_animation("Bite_Front"):
		return
	var anim: Animation = _anim_player.get_animation("Bite_Front")
	anim.loop_mode = Animation.LOOP_NONE
	_anim_player.stop()
	_anim_player.play("Bite_Front")

func _find_target() -> Enemy:
	var nearest: Enemy = null
	var nearest_dist: float = INF
	var origin: Vector3 = global_position
	for body in _range_area.get_overlapping_bodies():
		var parent := body.get_parent()
		if parent is Enemy:
			var d: float = body.global_position.distance_to(origin)
			if d < nearest_dist:
				nearest_dist = d
				nearest = parent
	return nearest
