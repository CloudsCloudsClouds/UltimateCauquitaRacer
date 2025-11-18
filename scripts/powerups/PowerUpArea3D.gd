extends Area3D

@export var effect_scene: PackedScene # The scene for the effect to apply (e.g., SpeedBoostEffect.tscn)

func _ready():
	# Connect the body_entered signal to our custom handler
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	# Check if the colliding body is a PlayerCar
	# We use 'is' for type checking, assuming PlayerCar is defined with 'class_name'
	if body is PlayerCar:
		print("PowerUpArea3D: Player entered! Applying effect...")
		if effect_scene:
			var effect_node = effect_scene.instantiate()
			# Add the effect node as a child of the PlayerCar
			body.add_child(effect_node)
			print("PowerUpArea3D: Effect instantiated and added to player.")
		else:
			printerr("PowerUpArea3D: No effect_scene assigned for power-up!")

		# Remove the power-up item from the scene after it's collected
		queue_free()
