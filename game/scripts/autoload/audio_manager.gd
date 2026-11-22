extends Node
## 音频管理：BGM 循环、SFX 播放、BGM/SFX 音量分离控制与配置持久化。
## 监听 EventBus 事件自动触发对应音效；process_mode=ALWAYS 使暂停菜单中仍可播音。

const BGM_PATH: String = "res://assets/audio/bgm_watch.ogg"
const SFX_PATH: String = "res://assets/audio/sfx_%s.ogg"
const SETTINGS_PATH: String = "user://settings.cfg"
const SFX_POOL_SIZE: int = 8

const SFX_NAMES: Array[StringName] = [
	&"spawn", &"fire", &"hit", &"build", &"wave",
	&"alarm", &"win", &"lose", &"merge",
]

var bgm_volume: float = 0.55
var sfx_volume: float = 0.80

var _bgm: AudioStreamPlayer
var _bgm_playing: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _next_sfx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_players()
	load_settings()
	_connect_events()
	play_bgm()
	print("[AUDIO] ready bgm=%.2f sfx=%.2f" % [bgm_volume, sfx_volume])

func _setup_players() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BGM"
	_bgm.stream = load(BGM_PATH) as AudioStream
	_bgm.finished.connect(_on_bgm_finished)
	add_child(_bgm)

	for sfx_name in SFX_NAMES:
		var stream := load(SFX_PATH % str(sfx_name)) as AudioStream
		if stream != null:
			_sfx_streams[sfx_name] = stream

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		add_child(player)
		_sfx_players.append(player)

func _connect_events() -> void:
	EventBus.unit_spawned.connect(func(_t: StringName, _l: int): play_sfx(&"spawn"))
	EventBus.tower_fired.connect(func(_t: StringName, _target: StringName): play_sfx(&"fire"))
	EventBus.unit_hit.connect(func(_t: StringName, _d: int): play_sfx(&"hit"))
	EventBus.wave_started.connect(func(_w: int, _c: int): play_sfx(&"wave"))
	EventBus.base_hit.connect(func(_d: int, _hp: int): play_sfx(&"alarm"))
	EventBus.result_decided.connect(func(win: bool, _r: String): play_sfx(&"win" if win else &"lose"))

func _on_bgm_finished() -> void:
	if _bgm_playing:
		_bgm.play()

func _exit_tree() -> void:
	# 释放音频播放与流引用，避免 headless 退出时 OggVorbis 资源泄漏诊断
	_bgm_playing = false
	if _bgm != null:
		_bgm.stop()
		if _bgm.finished.is_connected(_on_bgm_finished):
			_bgm.finished.disconnect(_on_bgm_finished)
	for p in _sfx_players:
		p.stop()
		p.stream = null
	if _bgm != null:
		_bgm.stream = null
	_sfx_streams.clear()

# ---------- BGM ----------
func play_bgm() -> void:
	if _bgm == null or _bgm.stream == null:
		return
	_bgm_playing = true
	_apply_bgm_volume()
	if not _bgm.playing:
		_bgm.play()

func stop_bgm() -> void:
	_bgm_playing = false
	if _bgm != null:
		_bgm.stop()

# ---------- SFX ----------
func play_sfx(sfx_name: StringName) -> void:
	if not _sfx_streams.has(sfx_name) or _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	player.stream = _sfx_streams[sfx_name]
	player.volume_db = -80.0 if sfx_volume <= 0.0 else linear_to_db(sfx_volume)
	player.play()

# ---------- 音量 ----------
func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_apply_bgm_volume()

func get_bgm_volume() -> float:
	return bgm_volume

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)

func get_sfx_volume() -> float:
	return sfx_volume

func _apply_bgm_volume() -> void:
	if _bgm == null:
		return
	_bgm.volume_db = -80.0 if bgm_volume <= 0.0 else linear_to_db(bgm_volume)

# ---------- 持久化 ----------
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	var err: int = cfg.save(SETTINGS_PATH)
	if err == OK:
		print("[AUDIO] settings saved bgm=%.2f sfx=%.2f" % [bgm_volume, sfx_volume])
	else:
		push_warning("[AUDIO] settings save failed err=%d" % err)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	bgm_volume = float(cfg.get_value("audio", "bgm_volume", bgm_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	_apply_bgm_volume()

func get_debug_snapshot() -> Dictionary:
	return {
		"bgm_volume": snappedf(bgm_volume, 0.01),
		"sfx_volume": snappedf(sfx_volume, 0.01),
		"bgm_playing": _bgm_playing,
		"sfx_pool": _sfx_players.size(),
		"sfx_loaded": _sfx_streams.size(),
	}

const GDA_CALLABLE := ["get_debug_snapshot"]
