extends Marker2D

const OBSTACLE = preload("uid://mtkiq18r1rew")

var active: bool = true
var last_gap_y: float = -1.0
 
@onready var timer: Timer = $Timer
 
func _ready() -> void:
	EventBus.game_finished.connect(func(a): active = false)
	EventBus.pace_changed.connect(_on_pace_changed)
 
 
func _on_timer_timeout():
	if active == false:
		return
		
	var obstacle: Node2D = OBSTACLE.instantiate()
	obstacle.position.y = _pick_gap_y_random_safe()
	obstacle.gap_height = MechanicsManager.current_gap
	add_child(obstacle)
 
	_update_wait_time()
 
 
# na troca de pace: respiro
func _on_pace_changed(_n, new_speed, _g, _grav, _j) -> void:
	last_gap_y = -1.0
 
	var speed_delta = new_speed - MechanicsManager.world_speed
	
	# acelerou: respiro escalado pelo pace novo; só aplica se maior que o countdown atual
	if speed_delta > 0.0:
		
		# tempo que um obstáculo do pace novo leva para percorrer o spacing (ritmo do pace novo em segundos)
		var next_beat = MechanicsManager.current_spacing / new_speed
		
		# 1 beat + extra pelo salto de speed (teto 0.5s), reduzido pelo fator
		var breath = (next_beat + clamp(speed_delta * 0.002, 0.0, 0.5)) * 0.75
		if breath > timer.time_left:
			timer.wait_time = breath
			timer.start()
 
 
func _update_wait_time() -> void:
	var speed = max(MechanicsManager.world_speed, 1.0)
	timer.wait_time = MechanicsManager.current_spacing / speed
	timer.start()
 
 
func _pick_gap_y_random() -> int:
	var screen_height = get_viewport_rect().size.y
	var score_half_height = MechanicsManager.current_gap / 2.0 - MechanicsManager.SCORE_PADDING
	
	var min_y = score_half_height - position.y
	var max_y = screen_height - position.y - score_half_height
	
	var random_y = randi_range(int(ceil(min_y)), int(ceil(max_y)))
	last_gap_y = random_y
	return random_y
 
 
func _pick_gap_y_random_safe() -> int:
	var screen_height = get_viewport_rect().size.y
	var score_half_height = MechanicsManager.current_gap / 2.0 - MechanicsManager.SCORE_PADDING
	
	var min_y = score_half_height - position.y
	var max_y = screen_height - position.y - score_half_height
	var random_y = randi_range(int(ceil(min_y)), int(ceil(max_y)))
	
	var pace = MechanicsManager.get_current_pace()
	if last_gap_y >= 0.0:
		random_y = clamp(random_y,
			last_gap_y - pace["max_travel_up"],
			last_gap_y + pace["max_travel_down"])
	
	last_gap_y = random_y
	return random_y
	
