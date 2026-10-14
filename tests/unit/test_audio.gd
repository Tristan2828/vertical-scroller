extends GutTest
## The synth, the music scores, the sound names the game asks for, the volume
## steps and screen shake. (Synth and score checks from Medieval Survival.)


func test_voice_has_the_requested_length_and_stays_in_range() -> void:
	var samples := Synth.voice(Synth.Wave.SQUARE, 440.0, 220.0, 0.1, 0.5, 0.002, 2.0, 0.5)
	assert_eq(samples.size(), int(0.1 * Synth.MIX_RATE))
	for value: float in samples:
		assert_true(absf(value) <= 0.5001)


func test_echo_extends_the_sound() -> void:
	var dry := Synth.voice(Synth.Wave.SINE, 440.0, 440.0, 0.1, 0.5)
	var wet := Synth.echo(dry, 0.05, 0.5, 2)
	assert_gt(wet.size(), dry.size())


func test_looping_stream_is_marked_to_loop() -> void:
	var stream := Synth.to_stream(PackedFloat32Array([0.0, 0.5, -0.5]), true)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.loop_end, 3)


func test_every_score_is_well_formed() -> void:
	for track: StringName in Tracks.ALL:
		var score: Dictionary = Tracks.ALL[track]
		var bars: int = score["chords"].size()
		assert_eq(score["lead"].size(), bars, "%s: one melody line per bar" % track)
		for line: String in score["lead"]:
			assert_eq(line.length(), MusicComposer.STEPS_PER_BAR, "%s melody line '%s'" % [track, line])
		for key: String in ["bass", "arp", "kick", "snare", "hat"]:
			var pattern: String = score[key]
			assert_true(pattern.is_empty() or pattern.length() == MusicComposer.STEPS_PER_BAR, "%s %s" % [track, key])
		assert_true(Synth.Wave.has(score["lead_wave"]) and Synth.Wave.has(score["arp_wave"]), "%s waves" % track)


func test_every_track_music_asks_for_exists() -> void:
	for track: StringName in Music.RENDER_ORDER:
		assert_true(Tracks.ALL.has(track), str(track))
	for script_path: String in ["res://src/main/main.gd", "res://src/stage/stage.gd", "res://src/shop/shop.gd",
			"res://src/lobby/lobby.gd", "res://src/ui/run_summary.gd"]:
		for track: String in _names_in(script_path, "Music.play(&\""):
			assert_true(Tracks.ALL.has(StringName(track)), "%s asks for track '%s'" % [script_path, track])


func test_rendered_music_has_exact_loop_length_and_safe_level() -> void:
	var score: Dictionary = Tracks.BOSS
	var samples := MusicComposer.render(score)
	var step_samples := int(60.0 / float(score["bpm"]) / 4.0 * Synth.MIX_RATE)
	assert_eq(samples.size(), score["chords"].size() * MusicComposer.STEPS_PER_BAR * step_samples)
	var peak := 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	assert_almost_eq(peak, MusicComposer.TARGET_PEAK, 0.001)


func test_music_is_deterministic() -> void:
	assert_eq(MusicComposer.render(Tracks.MENU), MusicComposer.render(Tracks.MENU))


func test_chords_follow_the_scale() -> void:
	# A minor, chord on degree 0: A C E.
	assert_eq(MusicComposer.chord_notes(45, Tracks.MINOR, 0), [57, 60, 64])
	assert_eq(MusicComposer.scale_note(Tracks.MINOR, 7), 12, "step 7 = an octave up")


## A typo in a sound name would be silent, so check every Sfx.play in the game.
func test_every_sound_the_game_plays_exists() -> void:
	var found := 0
	for script_path: String in _scripts("res://src"):
		for sound: String in _names_in(script_path, "Sfx.play(&\""):
			found += 1
			assert_true(Sfx.has_sound(StringName(sound)), "%s plays '%s'" % [script_path, sound])
	assert_gt(found, 15, "found the game's sounds")


func test_audio_has_its_own_buses() -> void:
	assert_gt(AudioServer.get_bus_index(&"Music"), 0)
	assert_gt(AudioServer.get_bus_index(&"SFX"), 0)
	Music.play(&"menu")
	Sfx.play(&"ui")
	assert_true(true, "playing in a headless run is harmless")


func test_volume_steps_stay_on_tens_and_in_range() -> void:
	assert_almost_eq(SettingsPanel.step_volume(0.8, 1), 0.9, 0.0001)
	assert_almost_eq(SettingsPanel.step_volume(0.75, 1), 0.9, 0.0001, "snaps to whole steps")
	assert_eq(SettingsPanel.step_volume(1.0, 1), 1.0)
	assert_eq(SettingsPanel.step_volume(0.0, -1), 0.0)


func test_screen_shake_fades_and_respects_the_setting() -> void:
	var shake := ScreenShake.new()
	assert_eq(shake.step(0.016, 1.0), Vector2.ZERO, "no trauma, no shake")
	shake.add(1.0)
	assert_eq(shake.step(0.016, 0.0), Vector2.ZERO, "off in Settings")
	shake.add(1.0)
	var offset := shake.step(0.016, 1.0)
	assert_true(absf(offset.x) <= ScreenShake.MAX_OFFSET and absf(offset.y) <= ScreenShake.MAX_OFFSET)
	shake.step(1.0, 1.0)
	assert_eq(shake.trauma, 0.0, "gone after a second")
	shake.add(5.0)
	assert_eq(shake.trauma, 1.0, "capped")


## The quoted names after `prefix` in a script, e.g. every Sfx.play(&"name".
func _names_in(script_path: String, prefix: String) -> Array[String]:
	var names: Array[String] = []
	var text := FileAccess.get_file_as_string(script_path)
	var at := text.find(prefix)
	while at >= 0:
		var start := at + prefix.length()
		names.append(text.substr(start, text.find("\"", start) - start))
		at = text.find(prefix, start)
	return names


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found
