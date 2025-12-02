extends AnimatableBody3D

@export var center: Vector3 = Vector3.ZERO   # centro de la órbita
@export var radius: float = 20.0             # radio del círculo
@export var height: float = 0.5              # altura fija sobre el suelo (Y)
@export var angular_speed: float = 1.0       # vueltas por segundo (1 = 1 vuelta/s)
@export var roll_speed_mul: float = 1.0      # qué tanto gira visualmente

var angle: float = 0.0

func _ready() -> void:
	# Si no quieres configurar el centro a mano, puedes usar tu posición inicial
	if center == Vector3.ZERO:
		center = Vector3(0.0, height, 0.0)

func _physics_process(delta: float) -> void:
	# Avanza el ángulo
	angle += angular_speed * TAU * delta  # TAU = 2*PI

	# Calcula posición en círculo sobre el plano XZ, altura fija
	var x = center.x + cos(angle) * radius
	var z = center.z + sin(angle) * radius
	global_position = Vector3(x, height, z)

	# Rotar la esfera para que parezca que rueda
	# Dirección tangente al círculo (aprox)
	var roll_angle := angular_speed * TAU * roll_speed_mul * delta
	rotate_z(roll_angle)
