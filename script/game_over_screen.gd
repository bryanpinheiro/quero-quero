extends Control

@onready var stats: RichTextLabel = %Stats

func _ready() -> void:
	hide()
	EventBus.game_finished.connect(_on_game_finished)
	

func _on_restart_pressed() -> void:
	hide()
	EventBus.restart_main_music.emit()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	hide()
	EventBus.stop_main_music.emit()
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	
	
func _on_game_finished(score: int) -> void:
	EventBus.stop_main_music.emit()
	await get_tree().physics_frame
	var max_score: int = GameManager.game_data.max_score
	stats.text = str("Pontuação: ", score, "\nRecorde: ", max_score)
	show()


func _on_restart_mouse_entered() -> void:
	EventBus.audio_button_hovered.emit()


func _on_menu_mouse_entered() -> void:
	EventBus.audio_button_hovered.emit()
