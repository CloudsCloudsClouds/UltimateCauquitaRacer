extends RigidBody3D

@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var max_speed := 20.0 
@export var accel_curve : Curve

var motor_input := 0

@export var tire_turn_speed := 2.0
@export var tire_max_turn_degress := 25

var hand_break := false
var is_slipping := false
@export var skid_marks : Array[GPUParticles3D]


func _ready() -> void:
	# Centro de masa más bajo → coche mucho más estable
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.5, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("handbreak"):
		hand_break = true
		is_slipping = true
	elif event.is_action_released("handbreak"):
		hand_break = false

	if event.is_action_pressed("accelerate"):
		motor_input = 1
	elif event.is_action_released("accelerate"):
		# solo soltamos si no estamos frenando
		if not Input.is_action_pressed("decelerate"):
			motor_input = 0

	if event.is_action_pressed("decelerate"):
		motor_input = -1
	elif event.is_action_released("decelerate"):
		if not Input.is_action_pressed("accelerate"):
			motor_input = 0


func _basic_steering_rotation(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	
	if turn_input != 0.0:
		$WheelFL.rotation.y = clampf(
			$WheelFL.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degress),
			deg_to_rad(tire_max_turn_degress)
		)
		$WheelFR.rotation.y = clampf(
			$WheelFR.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degress),
			deg_to_rad(tire_max_turn_degress)
		)
	else:
		$WheelFL.rotation.y = move_toward($WheelFL.rotation.y, 0.0, tire_turn_speed * delta)
		$WheelFR.rotation.y = move_toward($WheelFR.rotation.y, 0.0, tire_turn_speed * delta)


func _physics_process(delta: float) -> void:
	_basic_steering_rotation(delta)

	var id := 0
	for wheel in wheels:
		wheel.force_raycast_update()

		if wheel.is_colliding():
			_do_single_wheel_suspension(wheel)
			_do_single_wheel_acceleration(wheel, delta)
			_do_single_wheel_traccion(wheel, id)

		id += 1
	# El centro de masa ya está fijado en _ready()


func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)


func _do_single_wheel_traccion(ray: RaycastWheel, idx: int) -> void:
	var steer_side_dir := ray.global_basis.x
	var tire_vel := _get_point_velocity(ray.wheel.global_position)

	var speed_len := tire_vel.length()
	if speed_len < 0.001:
		return

	var steering_x_vel := steer_side_dir.dot(tire_vel)

	var grip_factor := absf(steering_x_vel / speed_len)
	grip_factor = clampf(grip_factor, 0.0, 1.0)

	var x_traction := ray.grip_curve.sample_baked(grip_factor)

	# skid marks
	if idx < skid_marks.size():
		skid_marks[idx].global_position = ray.get_collision_point() + Vector3.UP * 0.01
		skid_marks[idx].look_at(skid_marks[idx].global_position + global_basis.z)

		if not hand_break && grip_factor < 0.2:
			is_slipping = false
			skid_marks[idx].emitting = false

		if hand_break:
			x_traction = 0.01
			if not skid_marks[idx].emitting:
				skid_marks[idx].emitting = true
		elif is_slipping:
			x_traction = 0.1

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var base := (mass * gravity) / 4.0

	var x_force := -steer_side_dir * steering_x_vel * x_traction * base

	# fricción longitudinal (adelante/atrás) usando el forward de la rueda
	var forward_dir := -ray.global_basis.z
	var f_vel := forward_dir.dot(tire_vel)
	var z_traction := 0.05
	var z_force := -forward_dir * f_vel * z_traction * base
	
	var force_pos := ray.wheel.global_position - global_position
	apply_force(x_force, force_pos)
	apply_force(z_force, force_pos)


func _do_single_wheel_acceleration(ray: RaycastWheel, delta: float) -> void:
	var forward_dir := -ray.global_basis.z
	var vel := forward_dir.dot(linear_velocity)

	# Giro visual de la rueda
	ray.wheel.rotate_x((-vel * delta) / ray.wheel_radius)
	
	if ray.is_motor && motor_input != 0:
		var contact := ray.wheel.global_position
		var force_pos := contact - global_position
		
		var speed_ratio := clampf(vel / max_speed, -1.0, 1.0)
		var ac := accel_curve.sample_baked(absf(speed_ratio))
		var force_vector := forward_dir * acceleration * motor_input * ac
		apply_force(force_vector, force_pos)


func _do_single_wheel_suspension(ray: RaycastWheel) -> void:
	# Longitud deseada del resorte
	var desired_len := ray.rest_dist + ray.wheel_radius

	var contact := ray.get_collision_point()
	var spring_up_dir := ray.global_transform.basis.y

	var current_len := ray.global_position.distance_to(contact)
	var spring_len := current_len - ray.wheel_radius

	var max_len := desired_len + ray.over_extend
	spring_len = clampf(spring_len, 0.0, max_len)

	var offset := ray.rest_dist - spring_len
	offset = clampf(offset, -ray.rest_dist, ray.rest_dist)

	ray.wheel.position.y = -spring_len

	var spring_force := ray.spring_strength * offset

	var world_vel := _get_point_velocity(contact)
	var relative_velocity := spring_up_dir.dot(world_vel)
	var spring_damp_force := ray.spring_damping * relative_velocity

	var force_vector := (spring_force - spring_damp_force) * spring_up_dir

	var force_pos_offset := ray.wheel.global_position - global_position
	apply_force(force_vector, force_pos_offset)


#extends RigidBody3D
#
#@export var engine_force := 3000.0
#@export var max_speed := 30.0
#
#func _physics_process(delta: float) -> void:
	#var dir := 0.0
#
	#if Input.is_action_pressed("accelerate"): # W
		#dir += 1.0
	#if Input.is_action_pressed("decelerate"): # S
		#dir -= 1.0
#
	#if dir != 0.0:
		#var forward := -global_basis.z
		#forward.y = 0.0             # sin componente vertical
		#forward = forward.normalized()
#
		## Limitar velocidad para que no se dispare
		#var horizontal_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		#var speed := horizontal_vel.length()
		#if speed < max_speed:
			#apply_central_force(forward * dir * engine_force)
