extends Node

# Quantos pontos o jogador precisa fazer para o pace mudar
const POINTS_TO_CHANGE_PACE: int = 3

# Maior salto permitido entre paces na fase aleatória.
# Ordem: warmup (0) -> moderate (1) -> fast (2) -> sprint (3)
# 2 = bloqueia warmup <-> sprint | 1 = só paces vizinhos
const MAX_PACE_JUMP: int = 2

const START_PACE_INDEX: int = 1

const pace_settings: Dictionary = {
	"warmup":   { "obstacle_speed": 120.0, "spawn_spacing": 180.0, "gap_height": 80.0,  "max_travel_up": 70, "max_travel_down": 100, "gravity_weight": 2.3, "jump_strength": 300.0 },
	"moderate": { "obstacle_speed": 180.0, "spawn_spacing": 240.0, "gap_height": 75.0,  "max_travel_up": 80, "max_travel_down": 110, "gravity_weight": 1.8, "jump_strength": 280.0 },
	"fast":     { "obstacle_speed": 335.0, "spawn_spacing": 280.0, "gap_height": 70.0,  "max_travel_up": 55, "max_travel_down": 95, "gravity_weight": 1.2, "jump_strength": 230.0 },
	"sprint":   { "obstacle_speed": 465.0, "spawn_spacing": 350.0, "gap_height": 95.0, "max_travel_up": 40, "max_travel_down": 60, "gravity_weight": 2.5, "jump_strength": 440.0 }
}

const pace_order: Array[String] = ["warmup", "moderate", "fast", "sprint"]

const SPEED_BLUR_SETTINGS := {
	"fast":    {"streak_zone": 0.35, "length": 0.20, "flow_speed": 20.0},
	"sprint":  {},  #default
}

# Chance relativa de cada pace ser sorteado
const random_pace_chances: Dictionary = {
	"warmup": 5,
	"moderate": 20,
	"fast": 40,
	"sprint": 35
}

const SCORE_PADDING: float = 8.0
var current_pace_index: int = 0
var points_in_current_pace: int = 0

var current_speed: float = -1
var current_gap: float = -1
var current_spacing: float = -1
var world_speed: float = 0.0
var speed_lerp_rate: float = 1.5

func _ready() -> void:
	EventBus.scored.connect(_on_scored)
	EventBus.game_finished.connect(func(_s): current_speed = 0.0)
	_update_current_values()

 
func _process(delta):
	world_speed = lerp(world_speed, current_speed, speed_lerp_rate * delta)


func reset() -> void:
	points_in_current_pace = 0
	change_pace(START_PACE_INDEX)
	world_speed = current_speed


func _on_scored() -> void:
	points_in_current_pace += 1

	if points_in_current_pace < POINTS_TO_CHANGE_PACE:
		return

	points_in_current_pace = 0
	change_pace(_pick_random_pace_index())


func get_current_pace():
	var pace_name = pace_order[current_pace_index]
	var settings: Dictionary = pace_settings[pace_name]
	return settings
	
	
func change_pace(new_pace_index: int) -> void:
	current_pace_index = new_pace_index
	_update_current_values()
 
	# gear shift: pipes em tela foram espaçados pro pace antigo —
	# desacelera a convergência do world_speed pra suavizar a
	# compressão de cadência durante a transição
	speed_lerp_rate = 0.6
	get_tree().create_timer(1.5).timeout.connect(func(): speed_lerp_rate = 1.5)
 
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
	
	if SPEED_BLUR_SETTINGS.has(pace_name):
		PostFX.set_speed_visible(true)
		var b = SPEED_BLUR_SETTINGS[pace_name]
		if b.is_empty():
			PostFX.reset_defaults("CR_SpeedBlur2D")
		else:
			PostFX.set_speed_streak_zone(b.streak_zone)
			PostFX.set_speed_length(b.length)
			PostFX.set_speed_flow(b.flow_speed)
	else:
		PostFX.set_speed_visible(false)
		

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
