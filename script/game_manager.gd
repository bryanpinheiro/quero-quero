extends Node

const SAVE_PATH = "user://save.tres"

@export var game_data: GameData = GameData.new()

# TODO: criar botão para deletar o arquivo game data

func _ready() -> void:
	load_data()
	EventBus.game_finished.connect(_on_game_finished)

func save_data() -> void:
	game_data.score = 10
	var error: int = ResourceSaver.save(game_data, SAVE_PATH)
	
	
func load_data() -> void:
	var _loaded_data = ResourceLoader.load(SAVE_PATH)
	if _loaded_data == null:
		save_data()
	else:
		game_data = _loaded_data

func _on_game_finished(score: int) -> void:
	game_data.score = score
	if game_data.max_score < score:
		game_data.max_score = score
	save_data()
