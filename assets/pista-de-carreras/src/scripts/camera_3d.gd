extends Camera3D

@export var target: VehicleBody3D
@export var offset: Vector3= Vector3(0, 5, 5)
@export var speed: float =5.0


func _process(delta: float) -> void:
	
	if not target: return
	
	var pos = target.global_transform.origin + target.global_transform.basis * offset
	
	global_transform.origin = global_transform.origin.lerp(pos, delta *speed)
	
	look_at(target.global_transform.origin)
