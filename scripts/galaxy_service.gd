## GalaxyService – Autoload
## Prozedurale Galaxie-Generierung (Seed-basiert, deterministisch).
## Koordinatensystem:
##   World-Pos : absolute Spielwelt-Koordinaten (mit Floating Origin)
##   Map-Pos   : Galaxy-Koordinaten (normiert, kleine Zahlen)
##   Cell-Pos  : diskrete Zell-ID (Vector3i)
extends Node

# -----------------------------------------------------------------------
# Konstanten & Parameter
# -----------------------------------------------------------------------

const WORLD_TO_MAP_SCALE := 1e-7          # 1.000.000 World-Units = 0.1 Map
const CELL_SIZE_MAP := 0.1                 # Map-Einheiten pro Zelle

# Spiralarm-Parameter
@export var galaxy_seed: int = 1337
@export var system_count: int = 42000
@export var arm_count: int = 5
@export var spiral_tightness: float = 0.5
@export var arm_spread: float = 0.28
@export var interarm_fraction: float = 0.33
@export var arm_width_multiplier: float = 0.45
@export var interarm_width_multiplier: float = 1.9
@export var radial_power: float = 0.85
@export var core_fraction: float = 0.18
@export var core_radius: float = 0.22
@export var vertical_spread: float = 0.04
@export var galaxy_position_scale: float = 18.0
@export var galaxy_position_bias: float = 0.35
@export var galaxy_vertical_bias: float = 0.35

# Schwarzes-Loch-Zone
@export var black_hole_system_free_radius: float = 0.03
@export var black_hole_density_falloff_width: float = 0.9

# Jitter (System-Position innerhalb der Zelle)
@export var system_position_jitter_fraction: float = 0.15
@export var system_position_jitter_fraction_y: float = 0.2

# System-Neigung
@export var system_tilt_degrees_min: float = 2.0
@export var system_tilt_degrees_max: float = 8.0

# -----------------------------------------------------------------------
# Signale
# -----------------------------------------------------------------------

signal target_changed(system_cell: Vector3i)

# -----------------------------------------------------------------------
# Interner State
# -----------------------------------------------------------------------

var _systems: Array[Dictionary] = []          # generierte Systeme
var _cell_map: Dictionary = {}                # Vector3i → System-Dictionary
var _target_cell: Vector3i = Vector3i(INT32_MAX, INT32_MAX, INT32_MAX)
var _generated: bool = false

# -----------------------------------------------------------------------
# Koordinaten-Hilfsfunktionen
# -----------------------------------------------------------------------

static func world_to_map(world_pos: Vector3) -> Vector3:
	return world_pos * WORLD_TO_MAP_SCALE

static func map_to_world(map_pos: Vector3) -> Vector3:
	return map_pos / WORLD_TO_MAP_SCALE

static func map_to_cell(map_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(map_pos.x / CELL_SIZE_MAP),
		floori(map_pos.y / CELL_SIZE_MAP),
		floori(map_pos.z / CELL_SIZE_MAP)
	)

static func cell_to_map_center(cell: Vector3i) -> Vector3:
	return (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL_SIZE_MAP

static func cell_seed(cell: Vector3i, seed: int) -> int:
	# Einfacher, deterministischer Hash
	var h := seed
	h ^= cell.x * 2654435769
	h ^= cell.y * 2246822519
	h ^= cell.z * 3266489917
	h = (h ^ (h >> 16)) * 0x45d9f3b
	h = (h ^ (h >> 16)) * 0x45d9f3b
	return h ^ (h >> 16)

# -----------------------------------------------------------------------
# Galaxie-Generierung
# -----------------------------------------------------------------------

func generate(seed_override: int = -1) -> void:
	if seed_override >= 0:
		galaxy_seed = seed_override
	_systems.clear()
	_cell_map.clear()
	_generated = false

	var rng := RandomNumberGenerator.new()
	rng.seed = galaxy_seed

	var generated := 0
	var attempts := 0
	var max_attempts := system_count * 20

	while generated < system_count and attempts < max_attempts:
		attempts += 1
		var pos := _sample_galaxy_position(rng)
		var cell := map_to_cell(pos)

		# Pro Zelle nur ein System
		if _cell_map.has(cell):
			continue

		# Schwarzes-Loch-Zone prüfen
		var r_norm := pos.length() / (galaxy_position_scale * galaxy_position_bias)
		if r_norm < black_hole_system_free_radius:
			continue

		var system := _generate_system(cell, pos)
		_systems.append(system)
		_cell_map[cell] = system
		generated += 1

	_generated = true
	print("GalaxyService: %d Systeme generiert (Seed %d, %d Versuche)" % [generated, galaxy_seed, attempts])

func is_generated() -> bool:
	return _generated

func get_systems() -> Array[Dictionary]:
	return _systems

func has_system(cell: Vector3i) -> bool:
	return _cell_map.has(cell)

func get_system(cell: Vector3i) -> Dictionary:
	return _cell_map.get(cell, {})

func get_systems_in_radius(center_cell: Vector3i, radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var c := center_cell + Vector3i(dx, dy, dz)
				if _cell_map.has(c):
					result.append(_cell_map[c])
	return result

# -----------------------------------------------------------------------
# Ziel (Navigationsziel)
# -----------------------------------------------------------------------

func set_target(cell: Vector3i) -> void:
	_target_cell = cell
	target_changed.emit(cell)

func clear_target() -> void:
	_target_cell = Vector3i(INT32_MAX, INT32_MAX, INT32_MAX)
	target_changed.emit(_target_cell)

func get_target_cell() -> Vector3i:
	return _target_cell

func has_target() -> bool:
	return _target_cell != Vector3i(INT32_MAX, INT32_MAX, INT32_MAX)

# -----------------------------------------------------------------------
# Intern – Positions-Sampling (Spiralarm-Galaxie)
# -----------------------------------------------------------------------

func _sample_galaxy_position(rng: RandomNumberGenerator) -> Vector3:
	# Entscheide ob Inter-Arm oder Arm-System
	var in_arm := rng.randf() > interarm_fraction
	var arm_idx := rng.randi() % arm_count

	# Radialer Falloff
	var r_norm := pow(rng.randf(), 1.0 / radial_power)
	r_norm = clampf(r_norm, 0.0, 1.0)
	var r := r_norm * galaxy_position_scale * galaxy_position_bias

	# Winkel entlang Spiralarm
	var base_angle := (TAU / arm_count) * arm_idx
	var spiral_angle := base_angle + r_norm * TAU * spiral_tightness

	# Streuung
	var spread := arm_spread * (interarm_width_multiplier if not in_arm else arm_width_multiplier)
	var angle_offset := rng.randf_range(-spread, spread) * TAU
	var angle := spiral_angle + angle_offset

	var x := cos(angle) * r
	var z := sin(angle) * r
	var y := rng.randf_range(-1.0, 1.0) * vertical_spread * galaxy_vertical_bias * galaxy_position_scale

	# Jitter für Zell-Position
	return Vector3(x, y, z) + galaxy_position_bias * Vector3.ZERO

func _generate_system(cell: Vector3i, map_pos: Vector3) -> Dictionary:
	var s_seed := cell_seed(cell, galaxy_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = s_seed

	# Sternfarbe (Spektrum ohne Grün)
	var hue := _sample_star_hue(rng)
	var star_color := Color.from_hsv(hue, 0.7 + rng.randf() * 0.3, 0.9 + rng.randf() * 0.1)

	# Sternklasse → Radius
	var star_radius := rng.randf_range(0.3, 1.0)

	# Planeten
	var planet_count := rng.randi_range(0, 6)
	var planets: Array = []
	var last_orbit := star_radius + 0.05
	for _i in range(planet_count):
		var orbit := last_orbit + rng.randf_range(0.04, 0.12)
		last_orbit = orbit
		planets.append({
			"orbit_radius": orbit,
			"orbit_speed": rng.randf_range(0.3, 2.0),
			"orbit_phase": rng.randf() * TAU,
			"size": rng.randf_range(0.01, 0.05),
			"color": Color.from_hsv(rng.randf(), 0.3 + rng.randf() * 0.4, 0.5 + rng.randf() * 0.4),
		})

	# System-Neigung
	var tilt := rng.randf_range(system_tilt_degrees_min, system_tilt_degrees_max)

	# System-ID aus Zell-Koordinaten
	var sys_id := "%d_%d_%d" % [cell.x, cell.y, cell.z]

	return {
		"id": sys_id,
		"cell": cell,
		"map_pos": map_pos,
		"star_color": star_color,
		"star_radius": star_radius,
		"tilt_degrees": tilt,
		"planets": planets,
		"system_seed": s_seed,
	}

func _sample_star_hue(rng: RandomNumberGenerator) -> float:
	# Hue-Bereiche ohne Grün (~80°–180° = 0.22–0.5 normiert)
	var h := rng.randf()
	if h > 0.22 and h < 0.5:
		# Grün-Bereich überspringen → auf Rot oder Blau mappen
		h = 0.22 if h < 0.36 else 0.5
	return h
