extends Node

# Quantos pontos o jogador precisa fazer para o pace mudar
var POINTS_TO_CHANGE_PACE: int = 1
var points_in_current_pace: int = 0
var total_score: int = 0

# Maior salto permitido entre paces na fase aleatória.
# Ordem: warmup (0) -> moderate (1) -> fast (2) -> sprint (3)
# 2 = bloqueia warmup <-> sprint | 1 = só paces vizinhos
const MAX_PACE_JUMP: int = 2

const START_PACE_INDEX: int = 1

const pace_settings: Dictionary = {
	"warmup":   { "obstacle_speed": 120.0, "spawn_spacing": 220.0, "gap_height": 85.0,  "max_travel_up": 70, "max_travel_down": 100, "gravity_weight": 2.0, "jump_strength": 310.0 },
	"moderate": { "obstacle_speed": 180.0, "spawn_spacing": 240.0, "gap_height": 80.0,  "max_travel_up": 80, "max_travel_down": 110, "gravity_weight": 1.8, "jump_strength": 280.0 },
	"fast":     { "obstacle_speed": 335.0, "spawn_spacing": 260.0, "gap_height": 75.0,  "max_travel_up": 55, "max_travel_down": 95, "gravity_weight": 1.2, "jump_strength": 230.0 },
	"sprint":   { "obstacle_speed": 400.0, "spawn_spacing": 290.0, "gap_height": 100.0, "max_travel_up": 40, "max_travel_down": 60, "gravity_weight": 2.5, "jump_strength": 440.0 }
}

const pace_order: Array[String] = ["warmup", "moderate", "fast", "sprint"]

const SPEED_BLUR_SETTINGS := {
	"fast":    {"streak_zone": 0.35, "length": 0.20, "flow_speed": 20.0},
	"sprint":  {},  #default
}

# Chance relativa de cada pace ser sorteado
const random_pace_chances: Dictionary = {
	"warmup": 10,
	"moderate": 25,
	"fast": 35,
	"sprint": 30
}

const SCORE_PADDING: float = 8.0
var current_speed: float = -1
var current_gap: float = -1
var current_spacing: float = -1
var world_speed: float = 0.0
var speed_lerp_rate: float = 1.5

const PACE_CYCLE := 39
const pace_ban_ranges := {
	"warmup": [6, 38],
	"moderate": [12, 24],
	"sprint": [0, 5]
}
var current_pace_index: int = 0

func _ready() -> void:
	EventBus.scored.connect(_on_scored)
	EventBus.game_finished.connect(func(_s): current_speed = 0.0)
	_update_current_values()

 
func _process(delta):
	world_speed = lerp(world_speed, current_speed, speed_lerp_rate * delta)
	PostFX.set_speed(clampf((world_speed - 200.0) / 200.0, 0.0, 1.0))


func reset() -> void:
	points_in_current_pace = 0
	total_score = 0
	change_pace(START_PACE_INDEX)
	world_speed = current_speed


func _on_scored() -> void:
	points_in_current_pace += 1
	total_score += 1 
 
	var phase := total_score % PACE_CYCLE
	
	var hard_range: Array = pace_ban_ranges["moderate"]

	if phase > hard_range[0] and phase <= hard_range[1]:
		POINTS_TO_CHANGE_PACE = clampi(1 + (phase - 12) / 3, 1, 4)
	else:
		POINTS_TO_CHANGE_PACE = 1
		 
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
		var b = SPEED_BLUR_SETTINGS[pace_name]
		if b.is_empty():
			# DONE: merged juice pass owns the speed blur params now
			PostFX.reset_defaults("CR_Juice")
		else:
			PostFX.set_speed_streak_zone(b.streak_zone)
			PostFX.set_speed_length(b.length)
			PostFX.set_speed_flow(b.flow_speed)
		

func _pick_random_pace_index() -> int:
	var allowed_pace_indexes: Array[int] = []
	var total_chance:int = 0
		
	const REPICK_UNLOCK_PHASE := 6
	
	var phase := total_score % PACE_CYCLE

	for index in pace_order.size():
		
		# early game: pace sempre troca, sem repick
		if phase < REPICK_UNLOCK_PHASE and index == current_pace_index:
			continue
		
		# se diferença entre o index atual e o proximo 
		# for maior que o limite de mudança de pace ignora o index
		if absi(index - current_pace_index) > MAX_PACE_JUMP:
			continue
		
		var pace_name = pace_order[index]
		
		# pace banido nessa fase do ciclo? ignora o index
		if pace_ban_ranges.has(pace_name):
			var ban_range: Array = pace_ban_ranges[pace_name]
			
			if phase >= ban_range[0] and phase <= ban_range[1]:
				continue
	
		allowed_pace_indexes.append(index)
		total_chance += random_pace_chances[pace_name]

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
