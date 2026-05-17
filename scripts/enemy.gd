class_name Enemy
extends PathFollow3D

enum Kind { BASIC, SWIFT, OGRE, ARMORED, BOSS }

const CONFIG := {
	Kind.BASIC: {
		"hp": 10,
		"speed": 3.0,
		"reward": 10,
		"radius": 0.35,
		"height": 1.4,
		"color": Color(0.3, 0.75, 0.3),
		"damage_reduction": 0.0,
		"model_path": "res://models/Blob/Dog.gltf",
		"model_scale": 1.0,
		"model_y_offset": 0.0,
		"model_rotation_y": 180.0,
		"model_animation": "Walk",
		"model_death_animation": "Death",
	},
	Kind.SWIFT: {
		"hp": 6,
		"speed": 5.2,
		"reward": 6,
		"radius": 0.25,
		"height": 1.0,
		"color": Color(0.9, 0.35, 0.35),
		"damage_reduction": 0.0,
		"model_path": "res://models/Blob/Cat.gltf",
		"model_scale": 1.0,
		"model_y_offset": 0.0,
		"model_rotation_y": 180.0,
		"model_animation": "Walk",
		"model_death_animation": "Death",
	},
	Kind.OGRE: {
		"hp": 36,
		"speed": 1.8,
		"reward": 25,
		"radius": 0.55,
		"height": 2.0,
		"color": Color(0.45, 0.55, 0.85),
		"damage_reduction": 0.0,
		"model_path": "res://models/Big/Bunny.gltf",
		"model_scale": 1.5,
		"model_y_offset": 0.0,
		"model_rotation_y": 180.0,
		"model_animation": "Walk",
		"model_death_animation": "Death",
	},
	Kind.ARMORED: {
		"hp": 18,
		"speed": 2.4,
		"reward": 18,
		"radius": 0.45,
		"height": 1.5,
		"color": Color(0.55, 0.58, 0.62),
		"damage_reduction": 0.5,
		"model_path": "res://models/Big/Orc.gltf",
		"model_scale": 1.0,
		"model_y_offset": 0.0,
		"model_rotation_y": 180.0,
		"model_animation": "Walk",
		"model_death_animation": "Death",
	},
	Kind.BOSS: {
		"hp": 150,
		"speed": 1.6,
		"reward": 150,
		"radius": 0.9,
		"height": 2.6,
		"color": Color(0.55, 0.1, 0.15),
		"damage_reduction": 0.15,
		"model_path": "res://models/Flying/Dragon.gltf",
		"model_scale": 1.0,
		"model_y_offset": 1.0,
		"model_rotation_y": 180.0,
		"model_animation": "Flying_Idle",
		"model_death_animation": "Death",
	},
}

var kind: int = Kind.BASIC
var hp_multiplier: float = 1.0

var max_hp: int = 10
var hp: int = 10
var base_speed: float = 3.0
var reward: int = 10
var damage_reduction: float = 0.0

var _slow_strength: float = 0.0
var _slow_remaining: float = 0.0
var _poison_dps: float = 0.0
var _poison_remaining: float = 0.0
var _poison_accum: float = 0.0
var _reached_goal := false
var _anim_player: AnimationPlayer = null
var _body: CharacterBody3D = null

signal died(enemy: Enemy)
signal reached_goal(enemy: Enemy)

func _ready() -> void:
	loop = false
	rotation_mode = PathFollow3D.ROTATION_XYZ
	add_to_group("enemies")
	var cfg: Dictionary = CONFIG[kind]
	base_speed = cfg.speed
	reward = cfg.reward
	damage_reduction = cfg.damage_reduction
	max_hp = int(cfg.hp * hp_multiplier)
	hp = max_hp
	_build_visual()
	if kind == Kind.BOSS:
		GameManager.set_boss(self)
		AudioManager.play_sfx(AudioManager.SFX.BOSS_SPAWN)

func _process(delta: float) -> void:
	if _reached_goal:
		return
	var speed_mult: float = 1.0
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_strength = 0.0
		else:
			speed_mult = 1.0 - _slow_strength
	if _poison_remaining > 0.0:
		_poison_remaining -= delta
		_poison_accum += _poison_dps * delta
		while _poison_accum >= 1.0 and not _reached_goal:
			_poison_accum -= 1.0
			take_damage(1)
		if _poison_remaining <= 0.0:
			_poison_dps = 0.0
			_poison_accum = 0.0
	progress += base_speed * speed_mult * delta
	if not _reached_goal and progress_ratio >= 1.0:
		_reached_goal = true
		AudioManager.play_sfx(AudioManager.SFX.LIFE_LOST)
		if kind == Kind.BOSS:
			GameManager.clear_boss()
		reached_goal.emit(self)
		queue_free()

func take_damage(amount: int) -> void:
	if _reached_goal:
		return
	var effective: int = max(1, int(amount * (1.0 - damage_reduction)))
	hp -= effective
	if kind == Kind.BOSS:
		GameManager.notify_boss_hp(max(0, hp), max_hp)
	if hp <= 0:
		_reached_goal = true
		var burst_color: Color = CONFIG[kind].color
		Effects.spawn_burst(get_tree().current_scene, global_position + Vector3(0, 0.5, 0), burst_color)
		AudioManager.play_sfx(AudioManager.SFX.ENEMY_DIE)
		if kind == Kind.BOSS:
			GameManager.clear_boss()
		died.emit(self)
		_play_death_or_free()

func _play_death_or_free() -> void:
	var cfg: Dictionary = CONFIG[kind]
	var death_anim: String = cfg.get("model_death_animation", "")
	if _body != null:
		_body.collision_layer = 0
	if _anim_player != null and death_anim != "" and _anim_player.has_animation(death_anim):
		var anim: Animation = _anim_player.get_animation(death_anim)
		anim.loop_mode = Animation.LOOP_NONE
		_anim_player.animation_finished.connect(_on_death_anim_finished)
		_anim_player.play(death_anim)
	else:
		queue_free()

func _on_death_anim_finished(_anim_name: StringName) -> void:
	queue_free()

func apply_slow(strength: float, duration: float) -> void:
	if strength > _slow_strength:
		_slow_strength = strength
	if duration > _slow_remaining:
		_slow_remaining = duration

func apply_poison(dps: float, duration: float) -> void:
	if dps > _poison_dps:
		_poison_dps = dps
	if duration > _poison_remaining:
		_poison_remaining = duration

func _build_visual() -> void:
	var cfg: Dictionary = CONFIG[kind]
	var h: float = cfg.height
	var r: float = cfg.radius

	var body := CharacterBody3D.new()
	body.name = "Body"
	body.input_ray_pickable = false
	add_child(body)
	_body = body

	var model_path: String = cfg.get("model_path", "")
	if model_path != "" and ResourceLoader.exists(model_path):
		var scene: Node = load(model_path).instantiate()
		scene.scale = Vector3.ONE * cfg.get("model_scale", 1.0)
		scene.position.y = cfg.get("model_y_offset", 0.0)
		scene.rotation.y = deg_to_rad(cfg.get("model_rotation_y", 0.0))
		body.add_child(scene)
		var anim_name: String = cfg.get("model_animation", "")
		var anim_player := scene.find_child("AnimationPlayer") as AnimationPlayer
		if anim_player:
			_anim_player = anim_player
			if anim_name != "" and anim_player.has_animation(anim_name):
				var anim: Animation = anim_player.get_animation(anim_name)
				anim.loop_mode = Animation.LOOP_LINEAR
				anim_player.play(anim_name)
	else:
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = h
		capsule.radius = r
		mesh.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cfg.color
		mat.roughness = 0.7
		mesh.material_override = mat
		mesh.position.y = h * 0.5
		body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.height = h
	cap_shape.radius = r
	shape.shape = cap_shape
	shape.position.y = h * 0.5
	body.add_child(shape)
