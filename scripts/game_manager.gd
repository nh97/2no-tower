extends Node

enum State { SELECTING_DIFFICULTY, READY, WAVE_IN_PROGRESS, BETWEEN_WAVES, GAME_OVER, VICTORY }
enum Difficulty { EASY, NORMAL, HARD }

const TOTAL_WAVES := 5
const DEFAULT_TOWER_KIND := 0  # = Tower.Kind.MAGIC
const SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]

const DIFFICULTY_CONFIG := {
	Difficulty.EASY:   { "money": 150, "lives": 20, "hp_mult": 0.8, "label": "🌱 EASY" },
	Difficulty.NORMAL: { "money": 100, "lives": 10, "hp_mult": 1.0, "label": "⚔ NORMAL" },
	Difficulty.HARD:   { "money": 80,  "lives": 7,  "hp_mult": 1.2, "label": "🔥 HARD" },
}

var money: int = 0
var lives: int = 0
var wave: int = 0
var state: State = State.SELECTING_DIFFICULTY
var selected_tower_kind: int = DEFAULT_TOWER_KIND
var pending_sell_slot: PlacementSlot = null
var current_boss: Enemy = null
var current_difficulty: int = Difficulty.NORMAL
var enemy_hp_mult: float = 1.0
var game_speed: float = 1.0
var starting_lives: int = 0

signal money_changed(value: int)
signal lives_changed(value: int)
signal wave_changed(value: int)
signal state_changed(new_state: State)
signal selected_tower_changed(kind: int)
signal sell_request_changed(slot: PlacementSlot, refund: int)
signal boss_appeared(max_hp: int)
signal boss_hp_changed(hp: int, max_hp: int)
signal boss_defeated()
signal game_speed_changed(value: float)

func reset() -> void:
	money = 0
	lives = 0
	wave = 0
	selected_tower_kind = DEFAULT_TOWER_KIND
	pending_sell_slot = null
	current_boss = null
	enemy_hp_mult = 1.0
	starting_lives = 0
	set_game_speed(1.0)
	_set_state(State.SELECTING_DIFFICULTY)
	money_changed.emit(money)
	lives_changed.emit(lives)
	wave_changed.emit(wave)
	selected_tower_changed.emit(selected_tower_kind)
	sell_request_changed.emit(null, 0)
	boss_defeated.emit()

func start_game(difficulty: int) -> void:
	current_difficulty = difficulty
	var cfg: Dictionary = DIFFICULTY_CONFIG[difficulty]
	money = cfg.money
	lives = cfg.lives
	enemy_hp_mult = cfg.hp_mult
	starting_lives = cfg.lives
	money_changed.emit(money)
	lives_changed.emit(lives)
	_set_state(State.READY)

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func try_spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

func lose_life() -> void:
	if state == State.GAME_OVER:
		return
	lives = max(0, lives - 1)
	lives_changed.emit(lives)
	if lives == 0:
		_set_state(State.GAME_OVER)

func advance_wave() -> void:
	wave += 1
	wave_changed.emit(wave)
	_set_state(State.WAVE_IN_PROGRESS)

func finish_wave() -> void:
	if state == State.GAME_OVER:
		return
	if wave >= TOTAL_WAVES:
		_set_state(State.VICTORY)
	else:
		_set_state(State.BETWEEN_WAVES)

func select_tower(kind: int) -> void:
	selected_tower_kind = kind
	selected_tower_changed.emit(kind)

func request_sell(slot: PlacementSlot) -> void:
	pending_sell_slot = slot
	sell_request_changed.emit(slot, slot.get_refund())

func confirm_sell() -> void:
	if pending_sell_slot == null:
		return
	pending_sell_slot.sell()
	pending_sell_slot = null
	sell_request_changed.emit(null, 0)

func cancel_sell() -> void:
	pending_sell_slot = null
	sell_request_changed.emit(null, 0)

func set_boss(e: Enemy) -> void:
	current_boss = e
	boss_appeared.emit(e.max_hp)
	boss_hp_changed.emit(e.hp, e.max_hp)

func notify_boss_hp(hp: int, max_hp: int) -> void:
	boss_hp_changed.emit(hp, max_hp)

func clear_boss() -> void:
	current_boss = null
	boss_defeated.emit()

func set_game_speed(s: float) -> void:
	game_speed = s
	Engine.time_scale = s
	game_speed_changed.emit(s)

func cycle_game_speed() -> void:
	var idx: int = SPEED_OPTIONS.find(game_speed)
	var next_idx: int = (idx + 1) % SPEED_OPTIONS.size() if idx >= 0 else 0
	set_game_speed(SPEED_OPTIONS[next_idx])

func is_perfect_clear() -> bool:
	return starting_lives > 0 and lives == starting_lives

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
