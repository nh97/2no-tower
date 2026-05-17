extends Node

enum SFX {
	TOWER_FIRE,
	ENEMY_DIE,
	TOWER_PLACE,
	PLACE_FAIL,
	LIFE_LOST,
	WAVE_START,
	VICTORY,
	GAME_OVER,
	TOWER_SELL,
	BOSS_SPAWN,
	TOWER_FIRE_MAGIC,
	TOWER_FIRE_ICE,
	TOWER_FIRE_CANNON,
	TOWER_FIRE_LIGHTNING,
	TOWER_FIRE_POISON,
}

const SFX_POOL_SIZE := 6
const SAMPLE_RATE := 22050
const BGM_PATH := "res://audio/bgm.mp3"

var _sfx_streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _bgm_player: AudioStreamPlayer

func _ready() -> void:
	_build_sfx()
	_build_players()
	_try_play_bgm()

func play_sfx(kind: int) -> void:
	var stream: AudioStream = _sfx_streams.get(kind)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_next_player]
	_next_player = (_next_player + 1) % SFX_POOL_SIZE
	p.stop()
	p.stream = stream
	p.play()

func _build_players() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -6.0
	add_child(_bgm_player)

func _build_sfx() -> void:
	_sfx_streams[SFX.TOWER_FIRE]  = _make_tone(880.0, 880.0, 0.06, false, 0.25)
	_sfx_streams[SFX.ENEMY_DIE]   = _make_tone(600.0, 200.0, 0.18, false, 0.3)
	_sfx_streams[SFX.TOWER_PLACE] = _make_sequence([520.0, 780.0], 0.12, false, 0.28)
	_sfx_streams[SFX.PLACE_FAIL]  = _make_tone(180.0, 180.0, 0.18, true, 0.22)
	_sfx_streams[SFX.LIFE_LOST]   = _make_tone(200.0, 160.0, 0.35, true, 0.3)
	_sfx_streams[SFX.WAVE_START]  = _make_sequence([440.0, 660.0, 880.0], 0.3, false, 0.3)
	_sfx_streams[SFX.VICTORY]     = _make_sequence([261.63, 329.63, 392.0, 523.25], 0.6, false, 0.3)
	_sfx_streams[SFX.GAME_OVER]   = _make_tone(400.0, 100.0, 0.5, false, 0.3)
	_sfx_streams[SFX.TOWER_SELL]  = _make_sequence([520.0, 260.0], 0.15, false, 0.28)
	_sfx_streams[SFX.BOSS_SPAWN]  = _make_tone(200.0, 80.0, 0.45, false, 0.4)
	_sfx_streams[SFX.TOWER_FIRE_MAGIC]     = _make_tone(1200.0, 1500.0, 0.08, false, 0.22)
	_sfx_streams[SFX.TOWER_FIRE_ICE]       = _make_sequence([1800.0, 1400.0], 0.07, false, 0.22)
	_sfx_streams[SFX.TOWER_FIRE_CANNON]    = _make_tone(200.0, 70.0, 0.25, false, 0.4)
	_sfx_streams[SFX.TOWER_FIRE_LIGHTNING] = _make_sequence([3000.0, 600.0, 2800.0, 500.0, 2400.0, 400.0], 0.18, true, 0.32)
	_sfx_streams[SFX.TOWER_FIRE_POISON]    = _make_sequence([220.0, 280.0, 180.0, 240.0], 0.22, true, 0.3)

func _try_play_bgm() -> void:
	if not ResourceLoader.exists(BGM_PATH):
		return
	var stream: AudioStream = load(BGM_PATH)
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_player.stream = stream
	_bgm_player.play()

func _make_tone(freq_start: float, freq_end: float, duration: float, square: bool, volume: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var ratio := float(i) / float(n)
		var freq: float = lerp(freq_start, freq_end, ratio)
		phase += freq * TAU / SAMPLE_RATE
		var env: float = 1.0 - ratio
		var s: float
		if square:
			s = (1.0 if sin(phase) >= 0.0 else -1.0) * volume * env
		else:
			s = sin(phase) * volume * env
		data.encode_s16(i * 2, clampi(int(s * 32767.0), -32768, 32767))
	return _make_stream(data)

func _make_sequence(freqs: Array, total_duration: float, square: bool, volume: float) -> AudioStreamWAV:
	var note_duration: float = total_duration / float(freqs.size())
	var n_per_note := int(SAMPLE_RATE * note_duration)
	var total_n := n_per_note * freqs.size()
	var data := PackedByteArray()
	data.resize(total_n * 2)
	var idx := 0
	for note in freqs:
		var f: float = note
		var phase := 0.0
		for i in n_per_note:
			var ratio := float(i) / float(n_per_note)
			phase += f * TAU / SAMPLE_RATE
			var env: float = 1.0 - ratio
			var s: float
			if square:
				s = (1.0 if sin(phase) >= 0.0 else -1.0) * volume * env
			else:
				s = sin(phase) * volume * env
			data.encode_s16(idx * 2, clampi(int(s * 32767.0), -32768, 32767))
			idx += 1
	return _make_stream(data)

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
