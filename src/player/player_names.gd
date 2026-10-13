class_name PlayerNames
extends RefCounted
## Display names and player colors. Each player types a name on the title menu
## (Settings.player_name); without one, a player is called by their slot color.
## Pure helpers; Net keeps everyone's names in sync. (Copied from Medieval Survival.)

## Long enough for most names, short enough for lobby rows and name tags.
const MAX_LENGTH: int = 12
## Each player slot's ship color (the P/p pixels). No red: enemies are red.
const SLOT_COLORS: Array[Color] = [
	Color(0.25, 0.65, 0.95),
	Color(0.72, 0.45, 0.95),
	Color(0.45, 0.85, 0.4),
	Color(0.95, 0.78, 0.3),
]
## Matches SLOT_COLORS.
const SLOT_NAMES: Array[String] = ["Blue", "Purple", "Green", "Gold"]


## Trims the name, keeps only characters the pixel font can draw, and caps
## the length. Returns "" when nothing usable is left.
static func sanitize(text: String) -> String:
	var kept := ""
	for i: int in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code <= 126 and PixelFont.GLYPHS.has(char(code)):
			kept += char(code)
		elif code == 32 or code == 9:
			kept += " "
	while kept.contains("  "):
		kept = kept.replace("  ", " ")
	return kept.strip_edges().left(MAX_LENGTH).strip_edges()


## The name to show: the chosen one, or the slot color.
static func display(chosen: String, slot: int) -> String:
	return chosen if not chosen.is_empty() else SLOT_NAMES[slot % SLOT_NAMES.size()]


static func color_of(slot: int) -> Color:
	return SLOT_COLORS[slot % SLOT_COLORS.size()]
