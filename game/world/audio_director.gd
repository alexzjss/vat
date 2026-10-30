class_name AudioDirector
extends Node

## Executa o audio do jogo (M19): musica com fade, jingles, efeitos e ducking. E o unico codigo que fala com o
## AudioServer e com AudioStreamPlayer. A decisao de QUAL musica toca vem de `AudioRules` (puro); aqui so se executa.
##
## Sem driver de audio (`--headless`) nada toca e nenhum player e criado, mas todo o estado abaixo continua
## atualizado, para os testes conferirem. Sem `stream` o som e ignorado, sem erro.

## Quantos efeitos soam ao mesmo tempo; o excedente reaproveita o player mais antigo.
const SFX_POOL_SIZE: int = 8
const SILENT_DB: float = -80.0
const DUCK_ATTACK: float = 0.1
const DUCK_RELEASE: float = 0.3

## Falso em headless; testes podem forcar para checar o ramo sem som.
var audible: bool = DisplayServer.get_name() != "headless"

# Estado observavel.
var current_music_id: StringName = &""
var current_jingle_id: StringName = &""
var last_sfx_id: StringName = &""
var last_sfx_pitch: float = 1.0
var last_sfx_db: float = 0.0
var last_sfx_position: Vector2 = Vector2.ZERO
var sfx_played: int = 0
var music_changes: int = 0
var duck_db: float = 0.0
## Soma ao relogio dos cooldowns (testes avancam o tempo sem esperar).
var clock_offset: float = 0.0

var _music_players: Array[AudioStreamPlayer] = []
var _active_music: int = 0
var _music_base_db: float = 0.0
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _last_played: Dictionary[StringName, float] = {}
var _rng := RandomNumberGenerator.new()
var _fade_tween: Tween
var _duck_tween: Tween
var _jingle_token: int = 0
var _duck_token: int = 0

func _ready() -> void:
	_rng.randomize()
	if not audible:
		return
	for i: int in 2:
		_music_players.append(_make_player(AudioBuses.MUSIC))
	for i: int in SFX_POOL_SIZE:
		_sfx_players.append(_make_player(AudioBuses.EFFECTS))

func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else AudioBuses.MASTER
	add_child(p)
	return p

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0 + clock_offset

## Toca `def` no barramento Música com fade-in; a mesma faixa que ja toca nao reinicia. Sem `stream` nao toca.
func play_music(def: MusicDef, fade: float = 0.0) -> void:
	if def == null or def.stream == null:
		return
	if def.id == current_music_id and current_jingle_id == &"":
		return
	_cancel_jingle()
	current_music_id = def.id
	music_changes += 1
	if not audible:
		return
	_start_on_music_player(def, fade)

## Para a musica (e qualquer jingle) com fade-out.
func stop_music(fade: float = 0.0) -> void:
	_cancel_jingle()
	if current_music_id != &"":
		music_changes += 1
	current_music_id = &""
	if not audible:
		return
	_fade_out(_music_players[_active_music], fade)

## Toca um jingle no barramento Música, calando a musica. Com `resume`, volta a `resume_id` (achado em `bank`;
## vazio = silencio) quando o jingle termina. Sem `resume`, o silencio fica.
func play_jingle(def: MusicDef, resume: bool = false, resume_id: StringName = &"", bank: SoundBank = null) -> void:
	if def == null or def.stream == null:
		# Sem jingle a retomada acontece ja, como se ele tivesse durado zero segundos.
		if resume:
			_resume_music(resume_id, bank)
		return
	_jingle_token += 1
	var token: int = _jingle_token
	current_jingle_id = def.id
	if current_music_id != &"":
		music_changes += 1
	current_music_id = &""
	var length: float = def.stream.get_length()
	if audible:
		_fade_out(_music_players[_active_music], 0.0)
		var p: AudioStreamPlayer = _music_players[1 - _active_music]
		_prepare_player(p, def, false)
		_active_music = 1 - _active_music
		_music_base_db = def.volume_db
		p.volume_db = def.volume_db + duck_db
		p.play()
	if is_inside_tree():
		get_tree().create_timer(maxf(length, 0.01)).timeout.connect(_on_jingle_done.bind(token, resume, resume_id, bank))

func _on_jingle_done(token: int, resume: bool, resume_id: StringName, bank: SoundBank) -> void:
	if token != _jingle_token:
		return
	current_jingle_id = &""
	if resume:
		_resume_music(resume_id, bank)

func _resume_music(id: StringName, bank: SoundBank) -> void:
	if id == &"":
		return
	var def: MusicDef = bank.find_music(id) if bank != null else null
	if def != null:
		play_music(def, AudioRules.RETURN_FADE)

func _cancel_jingle() -> void:
	_jingle_token += 1
	current_jingle_id = &""

## Toca um efeito, respeitando o cooldown do som; o tom varia dentro de `pitch_variation`. Sem `stream` ou em
## cooldown nao toca. `position` fica registrada (efeitos ainda soam sem espacializacao).
func play_sfx(def: SoundDef, position: Vector2 = Vector2.ZERO) -> void:
	if def == null or def.stream == null:
		return
	var now: float = _now()
	if def.cooldown > 0.0 and _last_played.has(def.id) and now - _last_played[def.id] < def.cooldown:
		return
	_last_played[def.id] = now
	last_sfx_id = def.id
	last_sfx_pitch = AudioRules.pitch_scale(def.pitch_variation, _rng.randf_range(-1.0, 1.0))
	last_sfx_db = def.volume_db
	last_sfx_position = position
	sfx_played += 1
	if not audible:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stop()
	p.stream = def.stream
	p.bus = def.bus_name() if AudioServer.get_bus_index(def.bus_name()) >= 0 else AudioBuses.MASTER
	p.volume_db = def.volume_db
	p.pitch_scale = last_sfx_pitch
	p.play()

## Abaixa a musica em `db` (negativo) por `seconds` e solta devagar. Nao mexe no volume do barramento (e da Config).
func duck_music(db: float, seconds: float) -> void:
	_duck_token += 1
	var token: int = _duck_token
	duck_db = minf(db, 0.0)
	if audible:
		_tween_duck(duck_db, DUCK_ATTACK)
	if is_inside_tree():
		get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_on_duck_done.bind(token))
	else:
		duck_db = 0.0

func _on_duck_done(token: int) -> void:
	if token != _duck_token:
		return
	duck_db = 0.0
	if audible:
		_tween_duck(0.0, DUCK_RELEASE)

func _tween_duck(target: float, time: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_volume, _current_music_db() - _music_base_db, target, time)

func _current_music_db() -> float:
	return _music_players[_active_music].volume_db

func _set_duck_volume(v: float) -> void:
	_music_players[_active_music].volume_db = _music_base_db + v

## Executa comandos do `AudioRules`, em ordem. `bank` resolve os ids; id desconhecido conta como silencio.
func run(commands: Array[Dictionary], bank: SoundBank) -> void:
	for c: Dictionary in commands:
		var id: StringName = c.get("id", &"")
		var fade: float = c.get("fade", 0.0)
		match int(c.get("op", AudioRules.Op.NOOP)):
			AudioRules.Op.PLAY_MUSIC:
				var def: MusicDef = bank.find_music(id) if bank != null else null
				if def == null:
					stop_music(fade)
				else:
					play_music(def, fade)
			AudioRules.Op.STOP_MUSIC:
				stop_music(fade)
			AudioRules.Op.PLAY_JINGLE:
				var jingle: MusicDef = bank.find_music(id) if bank != null else null
				var resume: bool = c.get("resume", false)
				var next_id: StringName = c.get("next_id", &"")
				if jingle == null or jingle.stream == null:
					if resume:
						_resume_music(next_id, bank)
					else:
						stop_music(fade)
				else:
					play_jingle(jingle, resume, next_id, bank)

# --- Execucao real (so com driver de audio) ---

func _start_on_music_player(def: MusicDef, fade: float) -> void:
	var old: AudioStreamPlayer = _music_players[_active_music]
	_active_music = 1 - _active_music
	var p: AudioStreamPlayer = _music_players[_active_music]
	_prepare_player(p, def, def.loop)
	_music_base_db = def.volume_db
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade > 0.0:
		p.volume_db = SILENT_DB
		p.play()
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(p, "volume_db", def.volume_db + duck_db, fade)
		if old.playing:
			_fade_tween.tween_property(old, "volume_db", SILENT_DB, fade)
			_fade_tween.chain().tween_callback(old.stop)
	else:
		p.volume_db = def.volume_db + duck_db
		p.play()
		old.stop()

func _prepare_player(p: AudioStreamPlayer, def: MusicDef, loop: bool) -> void:
	p.stop()
	var s: AudioStream = def.stream
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop and w.loop_end <= 0:
			w.loop_end = int(w.get_length() * float(w.mix_rate))
		s = w
	elif s is AudioStreamOggVorbis:
		var o: AudioStreamOggVorbis = (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		o.loop = loop
		s = o
	p.stream = s
	p.pitch_scale = 1.0

func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if not p.playing:
		return
	if fade <= 0.0:
		p.stop()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(p, "volume_db", SILENT_DB, fade)
	_fade_tween.tween_callback(p.stop)
