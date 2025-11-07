class_name EightWaySprite
extends Sprite3D

@onready var current_camera := get_viewport().get_camera_3d()

@export var anim_frame: int = 0


func _physics_process(delta: float) -> void:
	if current_camera == null:
		return
	
	var p_fwd := -current_camera.global_transform.basis.z
	var fwd := global_transform.basis.z
	var left := global_transform.basis.x
	
	var l_dot := left.dot(p_fwd)
	var f_dot := fwd.dot(p_fwd)
	var row := 0
	flip_h = false
	
	if f_dot < -0.85:
		row = 0
	elif f_dot > 0.85:
		row = 4
	else:
		flip_h = l_dot > 0
		if abs(f_dot) < 0.3:
			row = 2
		elif f_dot < 0:
			row = 1
		else:
			row = 3
	frame = anim_frame + row * 4
