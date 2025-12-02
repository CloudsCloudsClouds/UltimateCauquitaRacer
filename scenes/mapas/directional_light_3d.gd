extends DirectionalLight3D

@export var rot_speed_deg: float = 10.0  # grados por segundo

func _process(delta: float) -> void:
	# Gira la luz alrededor del eje X (amanecer/atardecer)
	var angle := deg_to_rad(rot_speed_deg) * delta
	rotate_y(angle)
