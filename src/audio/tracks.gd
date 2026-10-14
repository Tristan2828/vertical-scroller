class_name Tracks
extends RefCounted
## The game's placeholder music, written as text scores (rendered by
## MusicComposer). Real tracks can replace them later as files (Music).
## (Format from Medieval Survival; the scores are new.)
##
## Each track loops 8 bars of 16 steps (sixteenth notes):
## - "chords": one scale degree per bar (0 = the key's root chord, 3 = fourth...).
## - "bass": "x" = chord root (low), "o" = chord fifth, "." = rest.
## - "arp": digits 0-2 = chord tones, 3 = root an octave up, "." = rest.
## - "lead": one 16-step string per bar. Digits are scale steps above the root
##   (0 = root, 7 = octave, 8/9 = higher), "-" holds the previous note, "." rests.
## - "kick" / "snare" / "hat": "x" = hit.
## - "lead_wave" / "arp_wave": Synth.Wave names; "pad": sustained chords on/off.
## Optional: "lead_drive" (crunch on the lead), "bass_volume" (default 0.32),
## "crash_bars" (bars that start with a crash cymbal), "tight_kick" (a short
## kick for fast patterns).

const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const HARMONIC_MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 11]
const DORIAN: Array[int] = [0, 2, 3, 5, 7, 9, 10]

## Title menu, lobby and run summary: slow and spacey, drifting chords.
const MENU: Dictionary = {
	"bpm": 72, "root": 50, "scale": MINOR,
	"chords": [0, 5, 2, 6, 0, 5, 3, 4],
	"bass": "x.......o.......",
	"arp": "0.1.2.3.2.1.0.1.",
	"arp_wave": "SINE",
	"lead_wave": "TRIANGLE",
	"pad": true,
	"lead": [
		"7-------6---4---", "5-------........", "4-------3---2---", "1-------........",
		"7-------6---9---", "8-------7-------", "5---4---3---2---", "4-------........",
	],
	"kick": "", "snare": "", "hat": "....x.......x...",
}

## Stages: a driving synth march with pulsing octave bass and a heroic lead.
const STAGE: Dictionary = {
	"bpm": 128, "root": 45, "scale": MINOR,
	"chords": [0, 5, 6, 4, 0, 5, 3, 4],
	"bass": "x.o.x.o.x.o.x.o.",
	"arp": "0123012301230123",
	"arp_wave": "SQUARE",
	"lead_wave": "SQUARE",
	"pad": false,
	"lead": [
		"4---4-5-7-----5-", "4-------2---0---", "1---1-2-4---2-1-", "2-------........",
		"4---4-5-7---9-8-", "7-------5---4---", "2---4---5---7---", "6-------4-------",
	],
	"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "..x...x...x...x.",
	"crash_bars": [0, 4], "tight_kick": true,
}

## Bosses: fast and urgent, harmonic minor, a gritty lead.
const BOSS: Dictionary = {
	"bpm": 152, "root": 47, "scale": HARMONIC_MINOR,
	"chords": [0, 0, 5, 5, 3, 3, 4, 4],
	"bass": "x.xox.xox.xox.xo",
	"arp": "0.1.2.3.0.1.2.3.",
	"arp_wave": "SQUARE",
	"lead_wave": "SAW",
	"lead_drive": 2.0,
	"pad": false,
	"lead": [
		"7-6-7-4-0---4-6-", "7---6---4---3---", "5-4-5-2-0---2-4-", "5---4---2---1---",
		"3-2-3-5-7---5-3-", "2---3---5---7---", "6-7-9-8-7---6---", "6-------........",
	],
	"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x.xx", "hat": "xxxxxxxxxxxxxxxx",
	"crash_bars": [0, 2, 4, 6], "tight_kick": true,
}

## Results and shop: a relaxed groove between stages.
const SHOP: Dictionary = {
	"bpm": 100, "root": 50, "scale": DORIAN,
	"chords": [0, 3, 0, 3, 1, 4, 0, 0],
	"bass": "x..x..o.x..x.o..",
	"arp": "0...2...1...3...",
	"arp_wave": "TRIANGLE",
	"lead_wave": "TRIANGLE",
	"pad": true,
	"lead": [
		"4---5---4-2-0---", "........3---5---", "4---5---7-5-4---", "........2-------",
		"3---4---3-1-0---", "5---4---3---1---", "2---4---5---4---", "0-------........",
	],
	"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
}

const ALL: Dictionary[StringName, Dictionary] = {
	&"menu": MENU, &"stage": STAGE, &"boss": BOSS, &"shop": SHOP,
}
