extends Node

const EXPLOSION = preload("res://scenes/explosion.tscn")






func explode(position: Vector3):
	var explosion_instance = EXPLOSION.instantiate()
	explosion_instance.position = position
	add_child(explosion_instance)
