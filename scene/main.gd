extends Node2D

var score: int = 0

@onready var background_player: AnimationPlayer = $BackgroundPlayer

func _ready() -> void:
	PostFX.enable_juice(true)
	PostFX.get_node("GameOverScreen").hide()
	MechanicsManager.reset()
	
	EventBus.play_main_music.emit()
	EventBus.scored.connect(_on_scored)
	
	PostFX.set_score(score)
	background_player.play("background_anim")
	
	
func _on_scored() -> void:
	score += 1
	PostFX.set_score(score)


func _exit_tree() -> void:
	PostFX.enable_juice(false)


func _on_player_died() -> void:
	background_player.pause()
	PostFX.set_speed_visible(false)
	EventBus.game_finished.emit(score)
