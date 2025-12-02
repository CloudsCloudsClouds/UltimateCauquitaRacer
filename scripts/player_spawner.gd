class_name PlayerSpawner
extends Node3D

@export var car: PackedScene
@export var l_length: float = 10.0
@export var l_width: float = 10.0

var spawned_cars = {}
@onready var camera_follower: CameraFollower = $CameraFollower

func _ready():
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)


func _process(_delta: float) -> void:
	PlayerManager.handle_join_input()
	PlayerManager.handle_leave_input()

func _on_player_joined(player_slot: int, device_id: int):
	print("Car Spawner: Player ", player_slot, " joined with device ", device_id)
	var new_car = car.instantiate() as PlayerCar
	new_car.acceleration = 1000
	new_car.max_speed = 30
	new_car.tire_max_turn_degress = 35
	add_child(new_car)

	# Initialize the car's input through its init function
	if new_car.has_method("init"):
		new_car.init(player_slot, device_id)
		new_car.position = Vector3(randf_range(-10, 10), 0.5, randf_range(-10, 10)) # Example spawn
		spawned_cars[player_slot] = new_car
		camera_follower.add_objective(new_car)
	else:
		printerr("Spawned car does not have an 'init' method!")

func _on_player_left(player_slot: int):
	print("Car Spawner: Player ", player_slot, " left.")
	if spawned_cars.has(player_slot):
		camera_follower.remove_objective(spawned_cars[player_slot])
		spawned_cars[player_slot].destroy_car()
		spawned_cars.erase(player_slot)

func _on_car_destroyed(mycar: PlayerCar):
	if spawned_cars.has(mycar):
		spawned_cars.erase(car)
		camera_follower.remove_objective(mycar)
