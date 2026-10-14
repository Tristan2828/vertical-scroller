class_name EnemyType
extends Resource
## Tunable numbers for one kind of enemy, air or ground (DESIGN.md §3 Enemies).
## Each type is a `.tres` file in `src/enemies/types/`, registered in
## EnemyTypes.ALL (its index there is the id sent over the network). Stage files
## name types by `key`.

enum Homing {
	## Follows its path shape.
	NONE,
	## After `homing_delay`, locks onto the nearest player and flies straight at
	## them (past them, if it misses).
	KAMIKAZE,
	## While hovering, keeps sliding over to the nearest player's side of the screen.
	TRACKER,
}

## Name used in stage files ("drone").
@export var key: String = ""
@export var display_name: String = "Enemy"
@export var max_hp: int = 30
## Body size: bullet hits and touching players.
@export var radius: float = 7.0

@export_group("Air")
## PixelArt sprite name (air enemies).
@export var sprite: String = ""
## HP a player loses on touching it (draft numbers, DESIGN.md §3).
@export var contact_damage: int = 10
## Blows up when it touches a player (kamikazes).
@export var dies_on_contact: bool = false
@export var homing: Homing = Homing.NONE
## Seconds after appearing before homing starts.
@export var homing_delay: float = 1.0
## Pixels per second while homing.
@export var homing_speed: float = 200.0

## Bosses: the stage's last enemy (its core), driven by the stage file's boss
## script (BossBrain) instead of a gun timer; the HUD shows its HP bar.
@export var is_boss: bool = false
## A destructible part of a boss (wing cannon, missile pod, hangar): flies with
## the boss core from an offset, has its own HP and gun or launcher.
@export var boss_part: bool = false
## Bosses: the path the boss flies (PathShapes.Id; big bosses sway less).
@export var boss_path: int = 6
## Launches an enemy of this key every `launch_interval` seconds (missile pods,
## hangars), flying `launch_shape` (a PathShapes name).
@export var launches: String = ""
@export var launch_interval: float = 3.0
@export var launch_shape: String = "straight"

@export_group("Drops")
## Scrap dropped on death (split into pieces), and the chance (0..1) of each
## rarer drop (draft numbers, DESIGN.md §3/§4).
@export var scrap: int = 1
@export var orb_chance: float = 0.0
@export var boost_chance: float = 0.0
@export var charge_chance: float = 0.0

@export_group("Gun")
## ShotPatterns.Id it fires, or -1 for none.
@export var shot_pattern: int = -1
## Seconds between volleys, and before the first one.
@export var fire_interval: float = 2.0
@export var first_shot_delay: float = 1.0
## HP one bullet takes from a player.
@export var bullet_damage: int = 10

@export_group("Ground")
## Ground objects sit on the map and scroll with it (turrets, tanks, buildings).
@export var ground: bool = false
## Gray-box size in pixels.
@export var size: Vector2 = Vector2(16, 16)
## Pixels per second it drives across the map (tanks); mirror flips x.
@export var drift: Vector2 = Vector2.ZERO
## Gun barrel length (0 = no barrel).
@export var barrel_length: float = 0.0
@export var body_color: Color = Color(0.32, 0.35, 0.33)
