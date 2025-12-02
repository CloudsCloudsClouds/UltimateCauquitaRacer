extends Node

@export var explosion: PackedScene


func explode(position: Vector3):
	var explosion_instance = explosion.instance()
	explosion_instance.position = position
	add_child(explosion_instance)
