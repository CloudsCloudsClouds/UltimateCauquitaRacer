class_name CameraFollower
extends Camera3D


@export var objectives: Array[PlayerCar] = []

# For linear interpolation
var look_objective := Vector3.ZERO


func add_objective(obj: PlayerCar) -> void:
	print_debug("Adding objective:", obj)
	objectives.append(obj)

func remove_objective(obj: PlayerCar) -> void:
	if objectives.has(obj):
		objectives.erase(obj)

func _physics_process(delta: float) -> void:
	if objectives.is_empty():
		return
	var center_position := Vector3.ZERO

	for i:PlayerCar in objectives:
		center_position += i.position
		center_position.y += 3

	center_position /= objectives.size()
	look_objective = look_objective.lerp(center_position, delta * 3)

	look_at(look_objective, Vector3.UP)
