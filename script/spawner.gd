extends Marker2D

const OBSTACLE = preload("uid://mtkiq18r1rew")

var active: bool = true

@onready var timer: Timer = $Timer

func _ready() -> void:
	EventBus.game_finished.connect(func(a): active = false)

func _on_timer_timeout():
	if active == false:
		return
		
	timer.wait_time = MechanicsManager.current_spacing / MechanicsManager.world_speed
	
	var screen_height = get_viewport_rect().size.y
	var score_half_height = MechanicsManager.current_gap / 2.0 - MechanicsManager.SCORE_PADDING
	var random_y = randi_range(
		int(ceil(score_half_height - position.y)),
		int(screen_height - position.y - score_half_height)
	)
	
	var obstacle: Node2D = OBSTACLE.instantiate()
	
	obstacle.position.y = random_y
	obstacle.speed = MechanicsManager.current_speed
	obstacle.target_speed = MechanicsManager.current_speed
	obstacle.gap_height = MechanicsManager.current_gap
	
	add_child(obstacle)
