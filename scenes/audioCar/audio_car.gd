class_name AudioCar
extends Node3D

@onready var parent: PlayerCar = get_parent()
#@onready var parent := get_parent()



@export var crash_sounds: Array[AudioStream]
@export var explosion_sounds: Array[AudioStream]

func _ready() -> void:
	await get_tree().process_frame

	parent.contact_monitor = true
	parent.max_contacts_reported = 4
	parent.connect("body_entered", _on_car_body_entered)

# c = coche que chocó
func _on_car_body_entered(body: Node3D) -> void:
	# Reproducir sonido en la posición del coche que chocó
	# Esto significa que se choco
	if body is PlayerCar:
		# Elige un sonido al azar
		var audio = crash_sounds.pick_random()
		# Crear nuevo recurso
		var audio_stream = AudioStreamPlayer3D.new()
		audio_stream.stream = audio

		# Variedad de sonido semi-infinita gratis!
		audio_stream.pitch_scale += randf_range(-0.1, 0.1)

		audio_stream.position = body.global_transform.origin
		add_child(audio_stream)
		audio_stream.play()
		# TODO: Has que el nodo se borre despues de acabar.
