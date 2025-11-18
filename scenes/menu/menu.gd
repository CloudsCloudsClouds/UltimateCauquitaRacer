extends Control

@export var play_scene: PackedScene
@export var config_scene: PackedScene


func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(play_scene)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_packed(config_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
