extends AnimatableBody3D

enum Mode { STATIC, UP_DOWN, ROTATE }

@export var mode: Mode = Mode.STATIC

# Movimiento vertical
@export var move_amplitude: float = 2.0   # cuánto sube/baja
@export var move_speed: float = 1.0       # qué tan rápido

# Rotación
@export var rotate_speed_deg: float = 45.0  # grados por segundo alrededor del eje Z

var base_position: Vector3

func _ready() -> void:
	base_position = global_position


func _physics_process(delta: float) -> void:
	match mode:
		Mode.UP_DOWN:
			# Movimiento senoidal en Y
			var t: float = Time.get_ticks_msec() / 1000.0 * move_speed
			var offset_y: float = sin(t) * move_amplitude
			global_position = Vector3(
				base_position.x,
				base_position.y + offset_y,
				base_position.z
			)

		Mode.ROTATE:
			# Rotar alrededor del eje Z
			var angle_rad: float = deg_to_rad(rotate_speed_deg) * delta
			rotate_y(angle_rad)

		Mode.STATIC:
			# No hacer nada
			pass
