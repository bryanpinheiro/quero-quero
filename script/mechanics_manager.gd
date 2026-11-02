extends Node

# Quantos pontos o jogador precisa fazer para o pace mudar
const POINTS_TO_CHANGE_PACE: int = 2

# Maior salto permitido entre paces na fase aleatória.
# Ordem: warmup (0) -> moderate (1) -> fast (2) -> sprint (3)
# 2 = bloqueia warmup <-> sprint | 1 = só paces vizinhos
const MAX_PACE_JUMP: int = 2

# Valores de cada pace
const pace_settings: Dictionary = {
	"warmup":   { "obstacle_speed": 200.0, "spawn_spacing": 200.0, "gap_height": 80.0, "gravity_weight": 0.025, "jump_strength": 250.0 },
	"moderate": { "obstacle_speed": 250.0, "spawn_spacing": 250.0, "gap_height": 100.0, "gravity_weight": 0.03, "jump_strength": 350.0 },
	"fast":     { "obstacle_speed": 300.0, "spawn_spacing": 300.0, "gap_height": 120.0, "gravity_weight": 0.015, "jump_strength": 200.0 },
	"sprint":   { "obstacle_speed": 350.0, "spawn_spacing": 400.0, "gap_height": 120.0, "gravity_weight": 0.015, "jump_strength": 200.0 }
}

# Ordem da progressão
const pace_order: Array[String] = ["warmup", "moderate", "fast", "sprint"]

# Chance relativa de cada pace ser sorteado depois do sprint
# (não precisam somar 100; o pace atual nunca é sorteado de novo)
const random_pace_chances: Dictionary = {
	"warmup": 15,
	"moderate": 55,
	"fast": 20,
	"sprint": 10
}

const SCORE_PADDING: float = 8.0

var current_pace_index: int = 0
var points_in_current_pace: int = 0

# O spawner lê estes dois valores ao criar cada obstáculo
var current_speed: float = -1
var current_gap: float = -1
var current_spacing: float = -1
var world_speed: float = 0.0

func _ready() -> void:
	EventBus.scored.connect(_on_scored)
	EventBus.game_finished.connect(func(_s): current_speed = 0.0)
	_update_current_values()

 
func _process(delta):
	world_speed = lerp(world_speed, current_speed, 1.5 * delta)


# Chame no _ready da main para começar uma partida do zero
func reset() -> void:
	points_in_current_pace = 0
	change_pace(0)
	world_speed = current_speed


func _on_scored() -> void:
	points_in_current_pace += 1

	if points_in_current_pace < POINTS_TO_CHANGE_PACE:
		return

	points_in_current_pace = 0
	change_pace(_pick_random_pace_index())


func change_pace(new_pace_index: int) -> void:
	current_pace_index = new_pace_index
	_update_current_values()

	var pace_name: String = pace_order[current_pace_index]
	var settings: Dictionary = pace_settings[pace_name]

	EventBus.pace_changed.emit(
		pace_name,
		settings["obstacle_speed"],
		settings["gap_height"],
		settings["gravity_weight"],
		settings["jump_strength"]
	)


func _update_current_values() -> void:
	var pace_name = pace_order[current_pace_index]
	var settings: Dictionary = pace_settings[pace_name]
	current_speed = settings["obstacle_speed"]
	current_gap = settings["gap_height"]
	current_spacing = settings["spawn_spacing"]

func _pick_random_pace_index() -> int:
	var allowed_pace_indexes: Array[int] = []
	var total_chance:int = 0

	for index in pace_order.size():
		
		# se o proximo pace for igual ao atual ignora o index
		if index == current_pace_index:
			continue
			
		# se diferença entre o index atual e o proximo 
		# for maior que o limite de mudança de pace ignora o index
		if absi(index - current_pace_index) > MAX_PACE_JUMP:
			continue

		allowed_pace_indexes.append(index)
		
		var pace_name = pace_order[index]
		total_chance += random_pace_chances[pace_name]

	# Nenhum pace possivel: continua no atual
	if allowed_pace_indexes.is_empty():
		return current_pace_index

	var dice_roll: int = randi_range(1, total_chance)

	# retorna o index do pace que o dado caiu
	for index in allowed_pace_indexes:
		var pace_name = pace_order[index]
		
		# verifica se o dado caiu na faixa do pace em relação a chance total
		dice_roll -= random_pace_chances[pace_name]
		if dice_roll <= 0:
			return index

	# retorna o ultimo elemento por segurança
	return allowed_pace_indexes.back()
