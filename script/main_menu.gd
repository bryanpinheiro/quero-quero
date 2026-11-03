extends Control

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")


func _on_fullscreen_pressed() -> void:
	var window = get_window()
	if window.mode == Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_play_mouse_entered() -> void:
	EventBus.audio_button_hovered.emit()


func _on_fullscreen_mouse_entered() -> void:
	EventBus.audio_button_hovered.emit()


func _on_clean_pressed() -> void:
	GameManager.clear_data()


func _on_sponsor_pressed() -> void:
	pass # Replace with function body.
