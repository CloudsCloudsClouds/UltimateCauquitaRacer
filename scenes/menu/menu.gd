extends Control




func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/pista-de-carreras/src/scenes/niveldemo.tscn")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/Options.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
