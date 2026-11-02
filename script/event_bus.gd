extends Node

signal scored
signal game_finished(score: int)
signal pace_changed(pace_name: String, obstacle_speed: float, gap_height: float, gravity_weight: float, jump_strength: float)

signal audio_player_jumped
signal audio_player_collided
signal audio_button_hovered
signal play_main_music
signal stop_main_music
signal restart_main_music
