class_name ShipStats
extends Resource
## One playable ship: numbers + main gun + sprite (DESIGN.md §3 Player ship).
## Ships are data: a new ship is mostly a new .tres in ships/ (listed in Ships.ALL).
## Each player will duplicate their ship's stats so in-run changes stay per player.

@export var display_name: String = ""
## One line for the lobby: what this ship's gun does.
@export var blurb: String = ""
@export var sprite: String = "ship"

@export_group("Body")
@export var max_hp: int = 100
## Pixels per second.
@export var move_speed: float = 240.0
@export var focus_speed: float = 110.0
## Enemy bullets only hit inside this (much smaller than the sprite).
@export var hitbox_radius: float = 2.5
## How close to the screen edge the ship's center can go.
@export var body_radius: float = 10.0

@export_group("Main gun")
## ShotPatterns.Id (stored as a number).
@export var gun_pattern: int = 0
@export var focus_pattern: int = 1
## Seconds between shots.
@export var fire_interval: float = 0.1
@export var focus_fire_interval: float = 0.0667
@export var bullet_speed: float = 600.0
@export var bullet_damage: int = 6
@export var focus_bullet_damage: int = 9
## Where shots appear, from the ship's center.
@export var muzzle_offset: Vector2 = Vector2(0, -12)

@export_group("Power levels")
## Main gun power 1-5 (DESIGN.md §3, draft): streams and damage at each level.
@export var spread_streams: Array[int] = [3, 5, 5, 7, 7]
@export var focus_streams: Array[int] = [2, 2, 3, 3, 4]
@export var power_damage: Array[float] = [1.0, 1.0, 1.3, 1.3, 1.6]

@export_group("Gun extras")
## Enemies one bullet can pass through (normal / focus shot).
@export var pierce: int = 0
@export var focus_pierce: int = 0
## Look of the bullets (ProjectileManager.Style: 0 bolt, 1 heavy bolt, 2 thin bolt).
@export var bolt_style: int = 0
@export var focus_bolt_style: int = 0
## Homing missiles (Hornet): missiles per volley at each power level (0 = none),
## the chance a shot comes with a volley, and their damage, speed and turn rate.
@export var missiles: Array[int] = [0, 0, 0, 0, 0]
@export var missile_chance: float = 0.0
@export var missile_damage: int = 10
@export var missile_speed: float = 360.0
@export var missile_turn: float = 5.0
