extends Node
## Sound effects (reach it anywhere as `Sfx`): `Sfx.play(&"scrap")`.
##
## Every sound is designed here with the Synth (waveforms, filters, layering,
## echo): placeholders until the audio pass. A finished sound file
## `assets/audio/sfx/<name>.wav` replaces its synth sound, so files can arrive
## a few at a time. (From Medieval Survival; the sounds are new.)
##
## Sounds play on every peer from events it already sees (never sent over the
## network), like the other effects.

const VOICES: int = 24
const BUS: StringName = &"SFX"
## Where finished sound files live: <name>.wav.
const SFX_DIR: String = "res://assets/audio/sfx/"

var _streams: Dictionary[StringName, AudioStream] = {}
## Sounds that come from a file instead of the synth.
var _from_file: Dictionary[StringName, bool] = {}
## Minimum seconds between two plays of the same sound (keeps swarms listenable).
var _min_gap: Dictionary[StringName, float] = {
	&"shoot": 0.07, &"hit": 0.05, &"pop": 0.04, &"boom": 0.06, &"scrap": 0.04, &"enemy_shot": 0.09,
	&"ui": 0.04, &"laser_charge": 0.2, &"hurt": 0.1,
}
var _last_played: Dictionary[StringName, float] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Set by stop_all(): nothing plays any more.
var _stopped: bool = false


func _ready() -> void:
	_rng.randomize()
	for i: int in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS
		add_child(voice)
		_voices.append(voice)
	_build_sounds()
	_load_files()


## Silences every voice for good (the game is quitting).
func stop_all() -> void:
	_stopped = true
	for voice: AudioStreamPlayer in _voices:
		voice.stop()


## Plays a sound. `volume_db` adjusts loudness; pitch gets a little random variety.
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null or _stopped:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sound, -1.0) < _min_gap.get(sound, 0.0):
		return
	_last_played[sound] = now
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	voice.play()


func has_sound(sound: StringName) -> bool:
	return _streams.has(sound)


## Every sound's name (tests, and the asset list).
func names() -> Array[StringName]:
	return _streams.keys()


## True when the sound plays from a file instead of the synth.
func is_from_file(sound: StringName) -> bool:
	return _from_file.has(sound)


## Swaps in finished sound files for the synth sounds that have one.
func _load_files() -> void:
	for sound: StringName in _streams.keys():
		var path := SFX_DIR + String(sound) + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_streams[sound] = stream
				_from_file[sound] = true


func _build_sounds() -> void:
	var W := Synth.Wave
	# Your gun: a soft, short blip (it plays all the time, so it must not be harsh).
	_add(&"shoot", Synth.voice(W.SQUARE, 980.0, 640.0, 0.045, 0.1, 0.002, 2.0, 0.35))
	# A bullet hits an enemy: a tiny metallic tick.
	_add(&"hit", Synth.mix([
		Synth.voice(W.NOISE, 4200.0, 2400.0, 0.03, 0.14, 0.001, 2.0, 0.6),
		Synth.voice(W.SQUARE, 1600.0, 1200.0, 0.025, 0.05, 0.001, 2.0, 0.4)]))
	# A small air enemy pops.
	_add(&"pop", Synth.mix([
		Synth.voice(W.NOISE, 1400.0, 200.0, 0.16, 0.26, 0.002, 1.6, 0.45),
		Synth.voice(W.SQUARE, 330.0, 90.0, 0.12, 0.12, 0.002, 2.0, 0.3)]))
	# A big enemy or a ground target blows up: a heavier crunch with a low thump.
	_add(&"boom", Synth.mix([
		Synth.voice(W.NOISE, 900.0, 60.0, 0.4, 0.34, 0.002, 1.4, 0.3),
		Synth.voice(W.SINE, 140.0, 40.0, 0.35, 0.42, 0.002, 1.8)]))
	# A boss (or a ship) goes down: a long rolling blast.
	_add(&"big_boom", Synth.echo(Synth.mix([
		Synth.voice(W.NOISE, 600.0, 30.0, 1.2, 0.4, 0.002, 1.3, 0.25),
		Synth.voice(W.SINE, 100.0, 28.0, 1.0, 0.45, 0.002, 1.4),
		Synth.voice(W.SAW, 160.0, 40.0, 0.6, 0.12, 0.002, 1.6, 0.2)]), 0.16, 0.35, 3))
	# Your ship took a hit: a harsh falling buzz.
	_add(&"hurt", Synth.mix([
		Synth.voice(W.SQUARE, 520.0, 140.0, 0.22, 0.3, 0.002, 1.5, 0.5, 30.0, 0.08),
		Synth.voice(W.NOISE, 2000.0, 500.0, 0.12, 0.18, 0.001, 2.0, 0.5)]))
	# A ship was shot down: an explosion with a sinking groan.
	_add(&"down", Synth.echo(Synth.mix([
		Synth.voice(W.NOISE, 800.0, 40.0, 0.7, 0.36, 0.002, 1.4, 0.3),
		Synth.voice(W.SAW, 300.0, 60.0, 0.8, 0.18, 0.004, 1.3, 0.3, 6.0, 0.03)]), 0.14, 0.3, 2))
	# Back in the fight: a rising warp.
	_add(&"respawn", Synth.echo(Synth.mix([
		Synth.voice(W.SINE, 300.0, 1200.0, 0.35, 0.22, 0.01, 1.2),
		_arpeggio([72, 76, 79, 84], 0.06, 0.16, W.TRIANGLE, 0.9)]), 0.08, 0.3, 2))
	# Pickups. Scrap: a bright coin blip.
	_add(&"scrap", Synth.sequence([
		Synth.voice(W.TRIANGLE, 1319.0, 1319.0, 0.035, 0.2, 0.002, 1.0),
		Synth.voice(W.TRIANGLE, 1760.0, 1760.0, 0.08, 0.2, 0.002, 2.0)]))
	# Power orb: a quick rising arpeggio.
	_add(&"power_up", Synth.echo(_arpeggio([67, 71, 74, 79, 83], 0.045, 0.22, W.SQUARE, 0.5), 0.06, 0.35, 2))
	# Boosts and special charges: a sparkly chime.
	_add(&"boost", Synth.echo(_arpeggio([79, 84, 88, 91, 96], 0.04, 0.2, W.TRIANGLE, 1.0), 0.06, 0.4, 3))
	# Mega Bomb: a deep boom under a white-noise blast and a falling sweep.
	_add(&"bomb", Synth.echo(Synth.mix([
		Synth.voice(W.NOISE, 3000.0, 80.0, 1.0, 0.36, 0.002, 1.3, 0.35),
		Synth.voice(W.SINE, 110.0, 30.0, 0.9, 0.45, 0.002, 1.3),
		Synth.voice(W.SAW, 1200.0, 100.0, 0.5, 0.1, 0.002, 1.5, 0.3)]), 0.15, 0.35, 3))
	# Shield: a shimmering hum that rises.
	_add(&"shield", Synth.echo(Synth.mix([
		Synth.voice(W.SINE, 440.0, 880.0, 0.5, 0.22, 0.02, 1.0, 1.0, 12.0, 0.03),
		Synth.voice(W.TRIANGLE, 660.0, 1320.0, 0.5, 0.12, 0.02, 1.2, 1.0, 12.0, 0.03)]), 0.09, 0.35, 2))
	# Enemy guns: a soft low "pew" (many enemies fire, so it stays in the back).
	_add(&"enemy_shot", Synth.voice(W.SQUARE, 420.0, 260.0, 0.07, 0.09, 0.002, 2.0, 0.3))
	# A laser warning line appears: a rising charge.
	_add(&"laser_charge", Synth.voice(W.SAW, 200.0, 900.0, 0.6, 0.12, 0.05, 0.6, 0.3, 18.0, 0.02))
	# Boss arrival: a two-tone alarm, three times.
	var alarm: Array[PackedFloat32Array] = []
	for i: int in 3:
		alarm.append(Synth.voice(W.SQUARE, 880.0, 880.0, 0.22, 0.18, 0.01, 0.6, 0.4))
		alarm.append(Synth.voice(W.SQUARE, 660.0, 660.0, 0.22, 0.18, 0.01, 0.6, 0.4))
	_add(&"warning", Synth.echo(Synth.sequence(alarm), 0.12, 0.25, 1))
	# The boss core opens: a heavy clank, then a rising tone.
	_add(&"core_open", Synth.sequence([
		Synth.mix([Synth.voice(W.NOISE, 1500.0, 300.0, 0.12, 0.3, 0.001, 2.0, 0.5),
			Synth.voice(W.SQUARE, 160.0, 120.0, 0.12, 0.2, 0.001, 2.0, 0.4)]),
		Synth.voice(W.SAW, 220.0, 660.0, 0.4, 0.14, 0.02, 1.2, 0.35)]))
	# Menus and the shop.
	_add(&"ui", Synth.voice(W.SINE, 900.0, 900.0, 0.03, 0.2, 0.001, 2.0))
	_add(&"buy", Synth.echo(Synth.sequence([
		Synth.voice(W.TRIANGLE, 988.0, 988.0, 0.05, 0.3, 0.002, 1.0),
		Synth.voice(W.TRIANGLE, 1319.0, 1319.0, 0.14, 0.3, 0.002, 2.0)]), 0.07, 0.3, 2))
	_add(&"victory", Synth.echo(_arpeggio([67, 72, 76, 79, 84, 88], 0.1, 0.24, W.SQUARE, 0.5), 0.12, 0.35, 3))
	_add(&"defeat", Synth.echo(Synth.sequence([
		Synth.voice(W.SAW, 330.0, 310.0, 0.28, 0.26, 0.005, 1.0, 0.35),
		Synth.voice(W.SAW, 262.0, 245.0, 0.28, 0.26, 0.005, 1.0, 0.35),
		Synth.voice(W.SAW, 196.0, 120.0, 0.7, 0.26, 0.005, 1.5, 0.35)]), 0.15, 0.3, 2))


func _add(sound: StringName, buffer: PackedFloat32Array) -> void:
	_streams[sound] = Synth.to_stream(buffer)


## Notes (MIDI numbers) played one after another.
func _arpeggio(notes: Array[int], note_seconds: float, volume: float, wave: Synth.Wave, brightness: float) -> PackedFloat32Array:
	var parts: Array[PackedFloat32Array] = []
	for i: int in notes.size():
		var hz := Synth.midi_to_hz(notes[i])
		var length := note_seconds * (2.5 if i == notes.size() - 1 else 1.0)
		parts.append(Synth.voice(wave, hz, hz, length, volume, 0.002, 1.2, brightness))
	return Synth.sequence(parts)
