extends Node

const EXPLOSION = preload("uid://bcka5sr1uysw3")



func explode(position: Vector3):
	var explosion_instance = EXPLOSION.instantiate()
	explosion_instance.position = position
	add_child(explosion_instance)
