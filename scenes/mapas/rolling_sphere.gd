extends AnimatableBody3D

# Piso del mapa (tu CSGBox3D)
@export var floor_path: NodePath
@export var margin: float = 2.0         # margen de seguridad respecto al borde
@export var height: float = 0.6         # altura fija sobre el piso

# Movimiento
@export var speed: float = 15.0         # velocidad
@export var roll_speed_mul: float = 1.5 # cuánto rueda visualmente

var _area_center: Vector3
var _half_x: float
var _half_z: float
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	randomize()

	if floor_path != NodePath(""):
		var floor = get_node(floor_path)
		# Para CSGBox3D la propiedad es "size"
		if floor is CSGBox3D:
			var size: Vector3 = floor.size
			_area_center = floor.global_position
			_half_x = size.x * 0.5 - margin
			_half_z = size.z * 0.5 - margin
		else:
			# fallback genérico
			_area_center = floor.global_position
			_half_x = 20.0
			_half_z = 20.0
	else:
		# Si no se asigna piso, usa algo por defecto
		_area_center = global_position
		_half_x = 20.0
		_half_z = 20.0

	# Velocidad inicial aleatoria en el plano XZ
	var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if dir.length() < 0.01:
		dir = Vector3(1, 0, 0)  # por si acaso
	_velocity = dir.normalized() * speed


func _process(delta: float) -> void:
	var pos: Vector3 = global_position

	# Movimiento lineal en XZ
	pos += _velocity * delta
	pos.y = height  # altura fija

	# Rebote en X
	if pos.x < _area_center.x - _half_x:
		pos.x = _area_center.x - _half_x
		_velocity.x *= -1.0
	elif pos.x > _area_center.x + _half_x:
		pos.x = _area_center.x + _half_x
		_velocity.x *= -1.0

	# Rebote en Z
	if pos.z < _area_center.z - _half_z:
		pos.z = _area_center.z - _half_z
		_velocity.z *= -1.0
	elif pos.z > _area_center.z + _half_z:
		pos.z = _area_center.z + _half_z
		_velocity.z *= -1.0

	global_position = pos

	# Rotación visual para que parezca que rueda
	if _velocity.length() > 0.001:
		var roll_angle := _velocity.length() * roll_speed_mul * delta
		var axis := Vector3(_velocity.z, 0.0, -_velocity.x).normalized()
		rotate(axis, roll_angle)
