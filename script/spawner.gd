extends Marker2D

const OBSTACLE = preload("uid://mtkiq18r1rew")

var active: bool = true

func _ready() -> void:
	EventBus.game_finished.connect(func(a): active = false)

func _on_timer_timeout():
	if active == false:
		return
	var random_y = randi_range(-90, 60)
	var obstacle: Node2D = OBSTACLE.instantiate()
	obstacle.position.y = random_y
	add_child(obstacle)
