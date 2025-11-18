# ultimate-cauquita-racer/scenes/rascast_car.gd
#
# Este script controla el comportamiento físico y la entrada de un coche de carreras 3D.
# Extiende RigidBody3D para aprovechar el motor de física de Godot y simula
# una suspensión, aceleración y tracción realistas para cada rueda mediante raycasts.
#
# Se integra con el sistema PlayerManager para gestionar la entrada específica de cada jugador,
# permitiendo el control multijugador con distintos dispositivos.
#
# Última actualización: Implementación de dirección analógica para una experiencia de
# conducción más suave y sensible.
class_name PlayerCar
extends RigidBody3D

## Array de objetos RaycastWheel que representan las ruedas del coche.
## Cada RaycastWheel gestiona la detección de colisiones con el suelo y la física individual.
@export var wheels: Array[RaycastWheel]

## La fuerza de aceleración máxima que el motor puede aplicar al coche.
@export var acceleration := 600.0

## La velocidad máxima que el coche puede alcanzar.
@export var max_speed := 20.0

## Curva de aceleración que define cómo varía la fuerza de aceleración
## en función de la velocidad actual del coche. Permite una aceleración
## más suave a bajas velocidades y una respuesta diferente a altas velocidades.
@export var accel_curve : Curve

## Entrada de motor actual (-1 para desacelerar, 0 para punto muerto, 1 para acelerar).
var motor_input := 0

## Velocidad a la que giran las ruedas delanteras al cambiar la dirección.
@export var tire_turn_speed := 5.0

## El ángulo máximo en grados que las ruedas delanteras pueden girar hacia la izquierda o la derecha.
@export var tire_max_turn_degress := 25

## Indica si el freno de mano está activado.
var hand_break := false

## Indica si el coche está derrapando (útil para efectos visuales como marcas de derrape).
var is_slipping := false

## Array de nodos GPUParticles3D utilizados para generar marcas de derrape visuales.
@export var skid_marks : Array[GPUParticles3D]

## El número de jugador asociado a este coche (asignado por PlayerManager).
@export var player: int

## Objeto DeviceInput específico para este jugador, que gestiona la entrada desde su dispositivo asignado.
var input: DeviceInput

## Señal emitida cuando el jugador asociado a este coche desea abandonar la partida (por ejemplo, al pulsar "join").
signal leave


## Inicializa el coche con el número de jugador y el ID del dispositivo de entrada.
## Esta función se espera que sea llamada por el PlayerManager cuando un jugador se une.
##
## @param player_num: El número de slot del jugador (ej. 0 para el jugador 1).
## @param device: El ID del dispositivo de entrada (-1 para teclado, 0+ para joypads).
func init(player_num: int, device: int):
	player = player_num
	input = DeviceInput.new(device)
	print("rascast_car: Initialized for player ", player, " with device ", device)


## Se llama cuando el nodo y todos sus hijos entran en el árbol de la escena.
func _ready() -> void:
	# Ajusta el centro de masa del coche hacia abajo para mejorar la estabilidad.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.5, 0.0)


## Procesa la entrada del jugador desde el dispositivo asignado.
## Actualiza las variables `hand_break`, `is_slipping` y `motor_input`
## basándose en las acciones de "handbreak", "accelerate" y "decelerate".
func get_input() -> void:
	# Asegura que la entrada esté inicializada antes de usarla.
	if input == null: return

	if input.is_action_pressed("handbreak"):
		hand_break = true
		is_slipping = true
	elif input.is_action_just_released("handbreak"):
		hand_break = false

	if input.is_action_pressed("accelerate"):
		motor_input = 1
	elif input.is_action_just_released("accelerate"):
		# Solo soltamos el acelerador si no estamos frenando para evitar un comportamiento errático.
		if not input.is_action_pressed("decelerate"):
			motor_input = 0

	if input.is_action_pressed("decelerate"):
		motor_input = -1
	elif input.is_action_just_released("decelerate"):
		# Solo soltamos el freno si no estamos acelerando.
		if not input.is_action_pressed("accelerate"):
			motor_input = 0


## Calcula y aplica la rotación de las ruedas delanteras basada en la entrada de dirección.
## Ahora implementa una dirección analógica, donde la fuerza del input (ej. joystick)
## determina el ángulo objetivo de giro de la rueda, y la rueda se mueve suavemente
## hacia ese ángulo.
##
## @param delta: El tiempo transcurrido desde el último frame (para movimientos dependientes del tiempo).
func _basic_steering_rotation(delta: float) -> void:
	# Asegura que la entrada esté inicializada antes de usarla.
	if input == null: return

	# Obtiene el valor crudo del eje de dirección (-1.0 a 1.0).
	var raw_turn_axis := input.get_axis("turn_right", "turn_left")
	# Calcula el ángulo objetivo de rotación en Y para las ruedas.
	var target_rotation_y = deg_to_rad(raw_turn_axis * tire_max_turn_degress)

	# Interpola suavemente la rotación actual de las ruedas hacia el ángulo objetivo.
	# `tire_turn_speed` controla la velocidad a la que las ruedas giran.
	$WheelFL.rotation.y = move_toward($WheelFL.rotation.y, target_rotation_y, tire_turn_speed * delta)
	$WheelFR.rotation.y = move_toward($WheelFR.rotation.y, target_rotation_y, tire_turn_speed * delta)


## Función de procesamiento de física, se llama a una velocidad fija.
## Este es el bucle principal de la física del coche.
##
## @param delta: El tiempo transcurrido desde el último tick de física.
func _physics_process(delta: float) -> void:
	# Asegura que la entrada esté inicializada antes de proceder.
	if input == null: return

	# Procesa la entrada del jugador.
	get_input()
	# Calcula la rotación de las ruedas delanteras.
	_basic_steering_rotation(delta)

	var id := 0
	# Itera sobre cada RaycastWheel para aplicar la física individual.
	for wheel in wheels:
		wheel.force_raycast_update() # Actualiza el raycast para detectar el suelo.

		if wheel.is_colliding(): # Si la rueda está en contacto con el suelo:
			_do_single_wheel_suspension(wheel)    # Aplica fuerzas de suspensión.
			_do_single_wheel_acceleration(wheel, delta) # Aplica fuerzas de aceleración/frenado.
			_do_single_wheel_traccion(wheel, id)    # Aplica fuerzas de tracción y derrape.

		id += 1

	# Detecta si el jugador quiere salir (por ejemplo, pulsando "join").
	if input.is_action_just_pressed("join"):
		emit_signal("leave")


## Calcula la velocidad de un punto específico en el espacio local del RigidBody3D.
## Esto es crucial para determinar la velocidad relativa de las ruedas respecto al chasis.
##
## @param point: La posición del punto en coordenadas locales del coche.
## @return: La velocidad lineal y angular combinada del punto en el espacio global.
func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)


## Aplica las fuerzas de tracción (lateral y longitudinal) a una rueda individual.
## También gestiona la lógica de derrape y la emisión de marcas de derrape.
##
## @param ray: El objeto RaycastWheel para el cual se calculan las fuerzas.
## @param idx: El índice de la rueda, usado para acceder a los efectos de marcas de derrape.
func _do_single_wheel_traccion(ray: RaycastWheel, idx: int) -> void:
	var steer_side_dir := ray.global_basis.x # Dirección lateral de la rueda.
	var tire_vel := _get_point_velocity(ray.wheel.global_position) # Velocidad global de la rueda.

	var speed_len := tire_vel.length()
	if speed_len < 0.001:
		return

	var steering_x_vel := steer_side_dir.dot(tire_vel) # Velocidad lateral de la rueda.

	var grip_factor := absf(steering_x_vel / speed_len) # Factor de deslizamiento lateral.
	grip_factor = clampf(grip_factor, 0.0, 1.0)

	var x_traction := ray.grip_curve.sample_baked(grip_factor) # Fuerza de tracción lateral basada en la curva de agarre.

	# Lógica para las marcas de derrape
	if idx < skid_marks.size():
		skid_marks[idx].global_position = ray.get_collision_point() + Vector3.UP * 0.01 # Posiciona las partículas.
		skid_marks[idx].look_at(skid_marks[idx].global_position + global_basis.z) # Orienta las partículas.

		if not hand_break and grip_factor < 0.2:
			is_slipping = false
			skid_marks[idx].emitting = false # Detiene la emisión si no hay derrape.

		if hand_break:
			x_traction = 0.01 # Reduce la tracción lateral drásticamente con freno de mano.
			if not skid_marks[idx].emitting:
				skid_marks[idx].emitting = true # Inicia la emisión si el freno de mano está activo.
		elif is_slipping:
			x_traction = 0.1 # Reduce la tracción lateral si está derrapando.

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var base := (mass * gravity) / 4.0 # Fuerza base de la rueda.

	var x_force := -steer_side_dir * steering_x_vel * x_traction * base # Fuerza lateral.

	# Fricción longitudinal (adelante/atrás) usando el forward de la rueda
	var forward_dir := -ray.global_basis.z # Dirección hacia adelante de la rueda.
	var f_vel := forward_dir.dot(tire_vel) # Velocidad longitudinal de la rueda.
	var z_traction := 0.05 # Factor de tracción longitudinal.
	var z_force := -forward_dir * f_vel * z_traction * base # Fuerza longitudinal.

	var force_pos := ray.wheel.global_position - global_position # Posición para aplicar la fuerza.
	apply_force(x_force, force_pos) # Aplica la fuerza lateral.
	apply_force(z_force, force_pos) # Aplica la fuerza longitudinal.


## Aplica las fuerzas de aceleración o frenado a una rueda individual.
## También gestiona la rotación visual de la rueda.
##
## @param ray: El objeto RaycastWheel para el cual se calculan las fuerzas.
## @param delta: El tiempo transcurrido desde el último tick de física.
func _do_single_wheel_acceleration(ray: RaycastWheel, delta: float) -> void:
	var forward_dir := -ray.global_basis.z # Dirección hacia adelante de la rueda.
	var vel := forward_dir.dot(linear_velocity) # Velocidad lineal del coche en la dirección de la rueda.

	# Giro visual de la rueda basado en la velocidad lineal del coche.
	ray.wheel.rotate_x((-vel * delta) / ray.wheel_radius)

	# Si la rueda es de motor y hay input de aceleración/desaceleración:
	if ray.is_motor and motor_input != 0:
		var contact := ray.wheel.global_position # Punto de contacto de la rueda.
		var force_pos := contact - global_position # Posición para aplicar la fuerza.

		var speed_ratio := clampf(vel / max_speed, -1.0, 1.0) # Proporción de la velocidad actual respecto a la máxima.
		var ac := accel_curve.sample_baked(absf(speed_ratio)) # Factor de aceleración de la curva.
		var force_vector := forward_dir * acceleration * motor_input * ac # Vector de fuerza de aceleración.
		apply_force(force_vector, force_pos) # Aplica la fuerza de aceleración.


## Aplica las fuerzas de suspensión y amortiguación a una rueda individual.
## Simula el comportamiento de un muelle y un amortiguador.
##
## @param ray: El objeto RaycastWheel para el cual se calculan las fuerzas.
func _do_single_wheel_suspension(ray: RaycastWheel) -> void:
	# Longitud deseada del resorte (distancia de reposo del raycast + radio de la rueda).
	var desired_len := ray.rest_dist + ray.wheel_radius

	var contact := ray.get_collision_point() # Punto de contacto del raycast.
	var spring_up_dir := ray.global_transform.basis.y # Dirección hacia arriba de la suspensión.

	var current_len := ray.global_position.distance_to(contact) # Longitud actual de la suspensión.
	var spring_len := current_len - ray.wheel_radius # Longitud real del muelle.

	var max_len := desired_len + ray.over_extend # Longitud máxima que el muelle puede extenderse.
	spring_len = clampf(spring_len, 0.0, max_len) # Clampa la longitud del muelle.

	var offset := ray.rest_dist - spring_len # Desplazamiento del muelle desde su posición de reposo.
	offset = clampf(offset, -ray.rest_dist, ray.rest_dist) # Clampa el desplazamiento.

	ray.wheel.position.y = -spring_len # Ajusta la posición visual de la rueda.

	var spring_force := ray.spring_strength * offset # Fuerza del muelle.

	var world_vel := _get_point_velocity(contact) # Velocidad del punto de contacto.
	var relative_velocity := spring_up_dir.dot(world_vel) # Velocidad relativa en la dirección de la suspensión.
	var spring_damp_force := ray.spring_damping * relative_velocity # Fuerza de amortiguación.

	var force_vector := (spring_force - spring_damp_force) * spring_up_dir # Vector de fuerza total de suspensión.

	var force_pos_offset := ray.wheel.global_position - global_position # Posición para aplicar la fuerza.
	apply_force(force_vector, force_pos_offset) # Aplica la fuerza de suspensión.
