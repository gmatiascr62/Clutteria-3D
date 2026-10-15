extends Node
## Efectos de sonido sintetizados en tiempo de carga (originales, sin
## archivos externos). Bus "SFX" con volumen y silencio configurables.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_build()
	apply_settings()


func apply_settings() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0 or Game.profile.is_empty():
		return
	var vol: float = Game.profile.settings.get("volume", 0.8)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.0001)))
	AudioServer.set_bus_mute(idx, Game.profile.settings.get("mute", false) or vol <= 0.001)


func play(name: String, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	# Toque de objeto: golpe corto con ruido filtrado + tono.
	_streams["pick"] = _make(0.12, func(t, i):
		var env := exp(-t * 40.0)
		return (sin(TAU * 520.0 * t) * 0.5 + (rng.randf() - 0.5) * 0.6) * env)
	# Trío: arpegio brillante.
	_streams["trio"] = _make(0.45, func(t, _i):
		var notes := [784.0, 988.0, 1175.0]
		var k := mini(2, int(t / 0.08))
		var lt: float = t - k * 0.08
		var env := exp(-lt * 9.0)
		return (sin(TAU * notes[k] * t) + 0.3 * sin(TAU * notes[k] * 2.0 * t)) * env * 0.5)
	# Cajón: deslizamiento (ruido grave con barrido).
	_streams["drawer"] = _make(0.35, func(t, _i):
		var env := sin(clampf(t / 0.35, 0.0, 1.0) * PI)
		return ((rng.randf() - 0.5) * 0.5 + sin(TAU * (90.0 + 60.0 * t) * t) * 0.4) * env * 0.7)
	# Caja/almohadón que se levanta.
	_streams["lift"] = _make(0.25, func(t, _i):
		return (rng.randf() - 0.5) * exp(-t * 14.0) * 0.8 + sin(TAU * 160.0 * t) * exp(-t * 20.0) * 0.4)
	# Caja misteriosa: fanfarria corta.
	_streams["mystery"] = _make(0.7, func(t, _i):
		var notes := [523.0, 659.0, 784.0, 1047.0]
		var k := mini(3, int(t / 0.12))
		var env := exp(-(t - k * 0.12) * 5.0)
		return (sin(TAU * notes[k] * t) * 0.6 + sin(TAU * notes[k] * 1.5 * t) * 0.2) * env * 0.5)
	# Moneda.
	_streams["coin"] = _make(0.3, func(t, _i):
		var f := 1318.0 if t < 0.07 else 1760.0
		return sin(TAU * f * t) * exp(-t * 12.0) * 0.45)
	# Error / tapado.
	_streams["deny"] = _make(0.18, func(t, _i):
		return (1.0 if fmod(t * 140.0, 1.0) < 0.5 else -1.0) * exp(-t * 18.0) * 0.18)
	# Bandeja llena / derrota.
	_streams["fail"] = _make(0.6, func(t, _i):
		return sin(TAU * (330.0 - 180.0 * t) * t) * exp(-t * 4.0) * 0.45)
	# Fregar.
	_streams["scrub"] = _make(0.16, func(t, _i):
		return (rng.randf() - 0.5) * sin(clampf(t / 0.16, 0.0, 1.0) * PI) * 0.5)
	# Pintura (whoosh largo).
	_streams["paint"] = _make(1.2, func(t, _i):
		return (rng.randf() - 0.5) * sin(clampf(t / 1.2, 0.0, 1.0) * PI) * 0.35)
	# Herramienta / éxito suave.
	_streams["tool"] = _make(0.35, func(t, _i):
		return sin(TAU * (600.0 + 900.0 * t) * t) * exp(-t * 7.0) * 0.4)
	# Botón.
	_streams["click"] = _make(0.05, func(t, _i):
		return sin(TAU * 900.0 * t) * exp(-t * 90.0) * 0.4)
	# Victoria.
	_streams["win"] = _make(1.0, func(t, _i):
		var notes := [523.0, 659.0, 784.0, 1047.0, 1319.0]
		var k := mini(4, int(t / 0.1))
		var env := exp(-(t - k * 0.1) * 3.0)
		return (sin(TAU * notes[k] * t) * 0.5 + sin(TAU * notes[k] * 0.5 * t) * 0.2) * env * 0.5)


func _make(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(gen.call(t, i), -1.0, 1.0)
		# Fundido para evitar clics.
		v *= minf(1.0, float(n - i) / 200.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
