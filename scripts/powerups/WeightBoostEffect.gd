extends Node3D

@export var duration := 5.0 # Duration of the weight boost in seconds
@export var weight_multiplier := 2.0 # Multiplier for mass

var player_car: PlayerCar
var original_mass: float

func _ready():
	# Ensure the parent is a PlayerCar before attempting to apply the effect
	player_car = get_parent() as PlayerCar
	if player_car:
		print("WeightBoostEffect: Applying weight boost to player.")
		original_mass = player_car.mass
		player_car.mass *= weight_multiplier
		# Calling reset_physics_transforms() can sometimes help the physics engine
		# re-evaluate the body's properties after a mass change, though it might not
		# always be strictly necessary for mass. It's good practice for RigidBody3D changes.
		player_car.reset_physics_interpolation()

		# Create and start a timer to revert the effect
		var timer = Timer.new()
		timer.wait_time = duration
		timer.timeout.connect(_on_timer_timeout)
		add_child(timer)
		timer.start()
	else:
		printerr("WeightBoostEffect: Parent is not a PlayerCar. Cannot apply effect.")
		queue_free() # Remove itself if not attached to a player car

func _on_timer_timeout():
	# Revert the mass back to original values
	# Check if player_car still exists and is valid before accessing its properties
	if player_car and is_instance_valid(player_car):
		print("WeightBoostEffect: Reverting weight boost.")
		player_car.mass = original_mass
		player_car.reset_physics_interpolation() # Revert physics transform changes too
	# Remove the effect node from the scene
	queue_free()
