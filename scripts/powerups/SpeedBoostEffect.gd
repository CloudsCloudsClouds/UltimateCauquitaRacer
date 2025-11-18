extends Node3D

@export var duration := 5.0 # Duration of the speed boost in seconds
@export var speed_multiplier := 1.5 # Multiplier for max_speed and acceleration

var player_car: PlayerCar
var original_max_speed: float
var original_acceleration: float

func _ready():
	# Ensure the parent is a PlayerCar before attempting to apply the effect
	player_car = get_parent() as PlayerCar
	if player_car:
		print("SpeedBoostEffect: Applying speed boost to player.")
		original_max_speed = player_car.max_speed
		original_acceleration = player_car.acceleration

		player_car.max_speed *= speed_multiplier
		player_car.acceleration *= speed_multiplier

		# Create and start a timer to revert the effect
		var timer = Timer.new()
		timer.wait_time = duration
		timer.timeout.connect(_on_timer_timeout)
		add_child(timer)
		timer.start()
	else:
		printerr("SpeedBoostEffect: Parent is not a PlayerCar. Cannot apply effect.")
		queue_free() # Remove itself if not attached to a player car

func _on_timer_timeout():
	# Revert the speed and acceleration back to original values
	if player_car and is_instance_valid(player_car): # Check if player_car still exists
		print("SpeedBoostEffect: Reverting speed boost.")
		player_car.max_speed = original_max_speed
		player_car.acceleration = original_acceleration
	# Remove the effect node from the scene
	queue_free()
