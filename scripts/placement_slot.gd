class_name PlacementSlot
extends StaticBody3D

const SLOT_RADIUS := 1.3
const SLOT_HEIGHT := 0.06
const NORMAL_ALBEDO := Color(0.9, 0.85, 0.3, 0.55)
const NORMAL_EMISSION := Color(0.9, 0.85, 0.3)
const FAIL_ALBEDO := Color(1.0, 0.3, 0.3, 0.75)
const FAIL_EMISSION := Color(1.0, 0.3, 0.3)
# touch のマウスエミュレーションで _on_input_event が同フレームに2回発火するのを抑止
const INPUT_DEBOUNCE_MSEC := 200

var occupied: bool = false
var _tower: Tower
var _disk: MeshInstance3D
var _disk_mat: StandardMaterial3D
var _flash_tween: Tween
var _last_input_msec: int = 0

func _ready() -> void:
	_build_visual()
	input_event.connect(_on_input_event)

func _build_visual() -> void:
	_disk = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = SLOT_RADIUS
	cyl.bottom_radius = SLOT_RADIUS
	cyl.height = SLOT_HEIGHT
	_disk.mesh = cyl
	_disk_mat = StandardMaterial3D.new()
	_disk_mat.albedo_color = NORMAL_ALBEDO
	_disk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disk_mat.emission_enabled = true
	_disk_mat.emission = NORMAL_EMISSION
	_disk_mat.emission_energy_multiplier = 0.5
	_disk.material_override = _disk_mat
	add_child(_disk)

	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = SLOT_RADIUS
	cyl_shape.height = SLOT_HEIGHT
	shape.shape = cyl_shape
	add_child(shape)

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var triggered := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			triggered = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			triggered = true
	if not triggered:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_input_msec < INPUT_DEBOUNCE_MSEC:
		return
	_last_input_msec = now
	if occupied:
		GameManager.request_sell(self)
	else:
		_try_place()

func _try_place() -> void:
	var kind: int = GameManager.selected_tower_kind
	var cost: int = Tower.CONFIG[kind].cost
	if not GameManager.try_spend(cost):
		_flash_red()
		return
	occupied = true
	_tower = Tower.new()
	_tower.kind = kind
	_tower.build_cost = cost
	add_child(_tower)
	AudioManager.play_sfx(AudioManager.SFX.TOWER_PLACE)

func get_refund() -> int:
	if _tower == null:
		return 0
	return _tower.build_cost / 2

func sell() -> void:
	if not occupied or _tower == null:
		return
	var refund: int = get_refund()
	GameManager.add_money(refund)
	_tower.queue_free()
	_tower = null
	occupied = false
	_disk.visible = true
	AudioManager.play_sfx(AudioManager.SFX.TOWER_SELL)

func _flash_red() -> void:
	AudioManager.play_sfx(AudioManager.SFX.PLACE_FAIL)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_disk_mat.albedo_color = FAIL_ALBEDO
	_disk_mat.emission = FAIL_EMISSION
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.4)
	_flash_tween.tween_callback(func() -> void:
		_disk_mat.albedo_color = NORMAL_ALBEDO
		_disk_mat.emission = NORMAL_EMISSION
	)
