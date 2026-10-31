extends Node

signal scored
signal game_finished(score: int)

# Sinais de áudio
signal audio_player_jumped
signal audio_player_collided
signal audio_button_hovered

# Novos sinais para controlar a música de fundo
signal play_main_music
signal stop_main_music
signal restart_main_music
