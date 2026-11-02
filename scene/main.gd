extends Node2D

var score: int = 0

@onready var score_label = %ScoreLabel
@onready var background_player: AnimationPlayer = $BackgroundPlayer

func _ready() -> void:
	MechanicsManager.reset()
	EventBus.play_main_music.emit()
	EventBus.scored.connect(_on_scored)
	score_label.text = str("[wave]", score)
	background_player.play("background_anim")
	
	
func _on_scored() -> void:
	score += 1
	score_label.text = str("[wave]", score)


func _on_player_died() -> void:
	background_player.pause()
	EventBus.game_finished.emit(score)
