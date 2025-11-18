extends Node3D

@onready var crash_player: AudioStreamPlayer3D = $CrashPlayer

func _ready() -> void:
	await get_tree().process_frame

	# Buscar todos los autos del grupo "car"
	var cars = get_tree().get_nodes_in_group("car")

	for c in cars:
		if c is RigidBody3D:
			# Activar monitor de colisiones para cada coche
			c.contact_monitor = true
			c.max_contacts_reported = 4

			# Conectar señal de colisión
			c.body_entered.connect(_on_car_body_entered.bind(c))


# c = coche que chocó
func _on_car_body_entered(_other_body: Node, c: RigidBody3D) -> void:
	# Reproducir sonido en la posición del coche que chocó
	play_crash(c.global_transform.origin)


func play_crash(at_position: Vector3) -> void:
	crash_player.global_position = at_position
	crash_player.stop()
	crash_player.play()
