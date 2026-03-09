## PlayerController
## 6DoF-Spielersteuerung im Weltraum.
## Bewegt und rotiert den Spieler relativ zu seiner eigenen Ausrichtung.
extends CharacterBody3D

# -----------------------------------------------------------------------
# Exports
# -----------------------------------------------------------------------

@export_group("Bewegung")
@export var acceleration: float = 25.0       # Beschleunigung in Units/s²
@export var max_speed: float = 20.0          # Maximale Geschwindigkeit
@export var boost_multiplier: float = 3.0    # Shift-Boost-Faktor
@export var damping: float = 0.85            # Dämpfung pro 60fps-Frame (0=sofort, 1=keine)

@export_group("Kamera / Maus")
@export var mouse_sensitivity: float = 0.002
@export var roll_speed: float = 1.5          # Rollgeschwindigkeit in rad/s

# -----------------------------------------------------------------------
# Node-Referenzen
# -----------------------------------------------------------------------

@onready var _camera: Camera3D = $Camera3D

# -----------------------------------------------------------------------
# Interner State
# -----------------------------------------------------------------------

var _mouse_delta: Vector2 = Vector2.ZERO

# -----------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	up_direction = Vector3.ZERO


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# -----------------------------------------------------------------------
# Input
# -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			release_mouse()
		else:
			capture_mouse()


# -----------------------------------------------------------------------
# Physik
# -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_process_look()
	_process_movement(delta)
	move_and_slide()


func _process_look() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_mouse_delta = Vector2.ZERO
		return

	# Yaw (links/rechts) – um lokale Y-Achse
	rotate_object_local(Vector3.UP, -_mouse_delta.x * mouse_sensitivity)
	# Pitch (hoch/runter) – um lokale X-Achse
	rotate_object_local(Vector3.RIGHT, -_mouse_delta.y * mouse_sensitivity)

	_mouse_delta = Vector2.ZERO


func _process_movement(delta: float) -> void:
	# Roll: Q = links kippen, E = rechts kippen (um lokale +Z-Achse)
	if Input.is_action_pressed("roll_left"):
		rotate_object_local(Vector3.BACK, roll_speed * delta)
	if Input.is_action_pressed("roll_right"):
		rotate_object_local(Vector3.BACK, -roll_speed * delta)

	# Richtungseingabe relativ zur eigenen Ausrichtung
	var wish_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):  wish_dir -= transform.basis.z
	if Input.is_action_pressed("move_backward"): wish_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):     wish_dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):    wish_dir += transform.basis.x
	if Input.is_action_pressed("move_up"):       wish_dir += transform.basis.y
	if Input.is_action_pressed("move_down"):     wish_dir -= transform.basis.y

	var speed := max_speed * (boost_multiplier if Input.is_action_pressed("boost") else 1.0)

	if wish_dir.length_squared() > 0.001:
		velocity += wish_dir.normalized() * acceleration * delta
		if velocity.length() > speed:
			velocity = velocity.normalized() * speed

	# Dämpfung (frame-rate-unabhängig)
	var damp_factor := pow(damping, delta * 60.0)
	velocity *= damp_factor
