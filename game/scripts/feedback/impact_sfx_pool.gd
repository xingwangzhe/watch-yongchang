extends Node
class_name ImpactSfxPool
## 打击音效池。所有 AudioStreamPlayer 在 configure 时预创建，命中时只轮换索引、不 new 节点。

const HIT_STREAM: AudioStream = preload("res://assets/audio/sfx_hit.ogg")
const THUD_STREAM: AudioStream = preload("res://assets/audio/sfx_enemy_hit.ogg")

var _hit_players: Array[AudioStreamPlayer] = []
var _thud_players: Array[AudioStreamPlayer] = []
var _hit_index: int = 0
var _thud_index: int = 0
var _rng := RandomNumberGenerator.new()
var _hit_volume: float = 0.55
var _thud_volume: float = 0.42
var _pitch_jitter: float = 0.12
var _volume_jitter_db: float = 1.2


func configure(
	hit_voices: int,
	thud_voices: int,
	hit_volume: float,
	thud_volume: float,
	pitch_jitter: float,
	volume_jitter_db: float
) -> void:
	_hit_volume = hit_volume
	_thud_volume = thud_volume
	_pitch_jitter = pitch_jitter
	_volume_jitter_db = volume_jitter_db
	_rebuild(_hit_players, HIT_STREAM, "HitVoice", maxi(1, hit_voices))
	_rebuild(_thud_players, THUD_STREAM, "ThudVoice", maxi(1, thud_voices))


func _rebuild(pool: Array[AudioStreamPlayer], stream: AudioStream, prefix: String, count: int) -> void:
	while pool.size() < count:
		var player := AudioStreamPlayer.new()
		player.name = "%s%d" % [prefix, pool.size()]
		player.stream = stream
		player.bus = "Master"
		add_child(player)
		pool.append(player)
	while pool.size() > count:
		var player: AudioStreamPlayer = pool.pop_back()
		if is_instance_valid(player):
			player.queue_free()


func play(weight: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var master := clampf(GameSettings.sfx_volume, 0.0, 1.0)
	if master <= 0.001:
		return
	var use_thud := weight >= 2
	var pool: Array[AudioStreamPlayer] = _thud_players if use_thud else _hit_players
	if pool.is_empty():
		return
	var player: AudioStreamPlayer
	if use_thud:
		player = pool[_thud_index]
		_thud_index = (_thud_index + 1) % pool.size()
	else:
		player = pool[_hit_index]
		_hit_index = (_hit_index + 1) % pool.size()
	player.pitch_scale = 1.0 + _rng.randf_range(-_pitch_jitter, _pitch_jitter)
	var layer_volume := _thud_volume if use_thud else _hit_volume
	var base_volume_db := linear_to_db(clampf(master * layer_volume, 0.0001, 1.0))
	player.volume_db = base_volume_db + _rng.randf_range(-_volume_jitter_db, _volume_jitter_db)
	player.play()


func voice_count() -> int:
	return _hit_players.size() + _thud_players.size()
