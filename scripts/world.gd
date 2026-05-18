extends Node3D

const GROUND_SIZE := 40.0
const PATH_POINTS: Array[Vector3] = [
	Vector3(-18, 0.05, -10),
	Vector3(-6, 0.05, -10),
	Vector3(-6, 0.05, 6),
	Vector3(8, 0.05, 6),
	Vector3(8, 0.05, -6),
	Vector3(18, 0.05, -6),
]
const WAVES: Array = [
	[ [Enemy.Kind.BASIC, 6] ],
	[ [Enemy.Kind.BASIC, 6], [Enemy.Kind.SWIFT, 4] ],
	[ [Enemy.Kind.BASIC, 6], [Enemy.Kind.SWIFT, 4], [Enemy.Kind.OGRE, 3] ],
	[ [Enemy.Kind.ARMORED, 5], [Enemy.Kind.SWIFT, 6], [Enemy.Kind.OGRE, 2] ],
	[ [Enemy.Kind.BASIC, 4], [Enemy.Kind.SWIFT, 4], [Enemy.Kind.BOSS, 1] ],
]
const SPAWN_INTERVAL := 1.0
const WAVE_DELAY := 3.0
const SLOT_POSITIONS: Array[Vector3] = [
	Vector3(-12, 0, -7),
	Vector3(-9, 0, 3),
	Vector3(3, 0, 9),
	Vector3(3, 0, 3),
	Vector3(11, 0, -3),
	Vector3(15, 0, -10),
]

var _path: Path3D
var _enemy_container: Node3D
var _spawn_timer: Timer
var _wave_timer: Timer
var _spawn_queue: Array[int] = []
var _alive_enemies: int = 0

func _ready() -> void:
	get_viewport().physics_object_picking = true
	_build_environment()
	_build_camera()
	_build_ground()
	_build_path()
	_build_goal_area()
	_build_placement_slots()
	_enemy_container = Node3D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)
	_setup_timers()
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.reset()

# --- Build helpers ---

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.65, 0.95)
	sky_mat.sky_horizon_color = Color(0.85, 0.85, 0.95)
	sky_mat.ground_horizon_color = Color(0.55, 0.6, 0.55)
	sky_mat.ground_bottom_color = Color(0.25, 0.3, 0.25)
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.7
	e.fog_enabled = true
	e.fog_density = 0.005
	e.fog_light_color = Color(0.75, 0.82, 0.95)
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-75), deg_to_rad(35), 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 19, 15)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 0, -2), Vector3.UP)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.input_ray_pickable = false
	add_child(ground)

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.55, 0.28)
	mat.roughness = 1.0
	mesh.material_override = mat
	ground.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 0.2, GROUND_SIZE)
	shape.shape = box
	shape.position.y = -0.1
	ground.add_child(shape)

func _build_path() -> void:
	_path = Path3D.new()
	_path.name = "Path"
	var curve := Curve3D.new()
	for p in PATH_POINTS:
		curve.add_point(p)
	_path.curve = curve
	add_child(_path)
	_build_road_strip()

func _build_road_strip() -> void:
	# Visualize the path by placing small brown plates along the curve.
	var curve := _path.curve
	var length := curve.get_baked_length()
	var step := 0.6
	var d := 0.0
	while d <= length:
		var pos := curve.sample_baked(d)
		var plate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 0.05, 1.6)
		plate.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.4, 0.25)
		mat.roughness = 0.9
		plate.material_override = mat
		plate.position = pos + Vector3(0, 0.02, 0)
		add_child(plate)
		d += step

func _build_goal_area() -> void:
	var area := Area3D.new()
	area.name = "Goal"
	var marker := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(2.0, 0.1, 2.0)
	marker.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.85, 0.2)
	mat.emission_energy_multiplier = 0.6
	marker.material_override = mat
	area.add_child(marker)
	area.position = PATH_POINTS[-1] + Vector3(0, 0.05, 0)
	add_child(area)

func _build_placement_slots() -> void:
	for pos in SLOT_POSITIONS:
		var slot := PlacementSlot.new()
		slot.position = pos + Vector3(0, 0.05, 0)
		add_child(slot)

func _setup_timers() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(_spawn_timer)

	_wave_timer = Timer.new()
	_wave_timer.one_shot = true
	_wave_timer.timeout.connect(_start_next_wave)
	add_child(_wave_timer)

# --- Wave control ---

func _start_next_wave() -> void:
	if GameManager.wave >= GameManager.TOTAL_WAVES:
		return
	GameManager.advance_wave()
	var idx: int = GameManager.wave - 1
	_spawn_queue.clear()
	for entry in WAVES[idx]:
		var k: int = entry[0]
		var count: int = entry[1]
		for i in count:
			_spawn_queue.append(k)
	_alive_enemies = 0
	_spawn_timer.start()
	AudioManager.play_sfx(AudioManager.SFX.WAVE_START)

func _on_spawn_timer() -> void:
	if _spawn_queue.is_empty():
		_spawn_timer.stop()
		return
	var k: int = _spawn_queue.pop_front()
	_spawn_enemy(k)

func _spawn_enemy(kind: int) -> void:
	var enemy := Enemy.new()
	enemy.kind = kind
	# Scale HP slightly per wave so later waves require more shots.
	var wave_index: int = GameManager.wave
	enemy.hp_multiplier = (1.0 + (wave_index - 1) * 0.2) * GameManager.enemy_hp_mult
	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	_path.add_child(enemy)
	_alive_enemies += 1

func _on_enemy_died(enemy: Enemy) -> void:
	GameManager.add_money(enemy.reward)
	_alive_enemies -= 1
	_check_wave_finished()

func _on_enemy_reached_goal(_enemy: Enemy) -> void:
	GameManager.lose_life()
	_alive_enemies -= 1
	_check_wave_finished()

func _check_wave_finished() -> void:
	if not _spawn_queue.is_empty() or _alive_enemies > 0:
		return
	GameManager.finish_wave()

func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.READY:
			_wave_timer.start(1.5)
		GameManager.State.BETWEEN_WAVES:
			_wave_timer.start(WAVE_DELAY)
		GameManager.State.GAME_OVER:
			_spawn_timer.stop()
			_wave_timer.stop()
			_spawn_queue.clear()
			AudioManager.play_sfx(AudioManager.SFX.GAME_OVER)
		GameManager.State.VICTORY:
			_spawn_timer.stop()
			_wave_timer.stop()
			_spawn_queue.clear()
			AudioManager.play_sfx(AudioManager.SFX.VICTORY)
