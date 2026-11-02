extends CharacterBody2D

signal died

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var alive: bool = true

var current_pace: String = "warmup"

var current_gravity_weight: float = 0.0375
var current_jump_weight: float = 200.0
var target_gravity: float = -1
var target_jump: float = -1

func _ready() -> void:
	animated_sprite.play("default")
	
	EventBus.pace_changed.connect(func(pace_name, _speed, _gap, new_gravity, new_jump):
		current_pace = pace_name
		target_gravity = new_gravity
		target_jump = new_jump
		print("Entrando no Pace: ", current_pace)
	)

func _physics_process(delta):
	current_gravity_weight = lerp(current_gravity_weight, target_gravity, 2.5 * delta)
	current_jump_weight = lerp(current_jump_weight, target_jump, 2.5 * delta)

	var raw_gravity = get_gravity().y
	var final_gravity = raw_gravity * current_gravity_weight
	velocity.y += final_gravity

	if alive:
		if Input.is_action_just_pressed("jump"):
			EventBus.audio_player_jumped.emit()
			velocity.y = -1 * current_jump_weight
			animation_player.play("fly_up")

	move_and_slide()

	if not animation_player.is_playing() and velocity.y > 0:
		$AnimatedSprite2D.rotation = lerp_angle($AnimatedSprite2D.rotation, deg_to_rad(45), delta * 5)

	if get_last_slide_collision() != null:
		game_over()


func _on_screen_exited():
	game_over()


func game_over() -> void:
	if alive == true:
		EventBus.audio_player_collided.emit()
		animated_sprite.pause()
		animation_player.stop()
		died.emit()
	alive = false
