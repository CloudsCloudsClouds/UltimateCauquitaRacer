class_name PowerupSpawner
extends Node3D

@export var powerups: Array[PackedScene]
@export var h_lenght := 10.0
@export var l_length := 10.0

@export var powerup_spawn_interval := 2.0
@export var random_time := 0.5

@onready var current_timer: float = powerup_spawn_interval
func _physics_process(delta: float) -> void:
	current_timer -= delta

	if current_timer <= 0:
		current_timer = 0
		spawn_powerup()
		current_timer = powerup_spawn_interval + randf_range(-random_time, random_time)

func spawn_powerup():
	var powerup = powerups.pick_random()
	var powerup_instance = powerup.instantiate()
	powerup_instance.position = Vector3(randf_range(-h_lenght, h_lenght), 0, randf_range(-l_length, l_length))
	add_child(powerup_instance)
