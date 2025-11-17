extends VehicleBody3D

@export var velocidad := 500
@export var freno := 100
@export var is_npc := false

func _physics_process(delta: float) -> void:
	
	if is_npc: return
	var direction = Input.get_axis("der","izq")
	
	
	if Input.is_action_pressed("frenar"):
		$trac1.brake = freno
		$trac2.brake = freno
	if Input.is_action_pressed("adelante"):
		$trac1.engine_force = velocidad
		$trac2.engine_force = velocidad
	if Input.is_action_pressed("atras"):
		$trac1.engine_force = -velocidad
		$trac2.engine_force = -velocidad
		
	if !Input.is_action_pressed("adelante") and  !Input.is_action_pressed("atras"):
		$trac1.engine_force = 0
		$trac2.engine_force = 0	
		
	if direction:
		$giro1.steering = direction * 4	
		$giro2.steering = direction * 4	
	else:
		$giro1.steering = 0
		$giro2.steering = 0
