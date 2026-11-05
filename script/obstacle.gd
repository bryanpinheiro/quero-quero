extends StaticBody2D

@onready var top_collision: CollisionShape2D = $CollisionShapeTop
@onready var bottom_collision: CollisionShape2D = $CollisionShapeBottom

@onready var score_area: Area2D = $ScoreArea
@onready var collision_score_area: CollisionShape2D = %CollisionShapeScoreArea

@onready var pipa_player: AnimationPlayer = $PipaPlayer

var gap_height: float = -1

const PIPE_HALF_HEIGHT: float = 96.0

func _ready() -> void:
	EventBus.game_finished.connect(func(_a):pipa_player.pause())
	pipa_player.play("pipa_anim")
	update_gap()


func update_gap() -> void:
	var half_gap = gap_height / 2.0
	var pipe_offset = half_gap + PIPE_HALF_HEIGHT
 
	top_collision.position.y = pipe_offset * -1
	bottom_collision.position.y = pipe_offset
 
	collision_score_area.shape.size.y = gap_height - MechanicsManager.SCORE_PADDING * 2.0
	collision_score_area.position.y = 0.0


func _physics_process(delta):
	position.x -= MechanicsManager.world_speed * delta
	if global_position.x < -64.0:
			queue_free()
			

func _on_score_area_body_entered(body):
	EventBus.scored.emit()
	
