extends StaticBody2D

@export var speed : float = 400
@onready var pipa_player: AnimationPlayer = $PipaPlayer

const OBSTACLE = preload("uid://mtkiq18r1rew")

func _ready() -> void:
	EventBus.game_finished.connect(func(a): 
		speed = 0
		pipa_player.pause()
	)
	pipa_player.play("pipa_anim")

func _physics_process(delta):
	position.x -= speed * delta


func _on_score_area_body_entered(body):
	EventBus.scored.emit()
