extends Control

var _display := DisplayModes.new()

@onready var option: OptionButton = $VBoxContainer/ResolutionRow/ResolutionOption
@onready var sponsor_popup: CanvasLayer = $SponsorPopup
@onready var resolution_row: HBoxContainer = $VBoxContainer/ResolutionRow


func _ready() -> void:
	if OS.get_name() == "Web":
		resolution_row.hide()
	else:
		_display.setup(option, get_window())
	option.item_selected.connect(_on_resolution_item_selected)
	sponsor_popup.get_node("Dimmer").gui_input.connect(_on_dimmer_gui_input)
	sponsor_popup.get_node("Center/Panel").gui_input.connect(_on_dimmer_gui_input)
	get_tree().auto_accept_quit = false


# safety: if the game quits while in low-res fullscreen, restore native
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_display.restore_native()
		get_tree().quit()


func _on_resolution_item_selected(index: int) -> void:
	_display.set_mode_if_fullscreen(get_window(), index)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")


func _on_fullscreen_pressed() -> void:
	_display.toggle_fullscreen(get_window(), option.selected)


func _on_play_mouse_entered() -> void:
	EventBus.audio_button_hovered.emit()


func _on_fullscreen_mouse_entered() -> void:
	EventBus.audio_button_hovered.emit()


func _on_clean_pressed() -> void:
	GameManager.clear_data()


func _on_sponsor_pressed() -> void:
	sponsor_popup.visible = true


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		sponsor_popup.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if sponsor_popup.visible and event.is_action_pressed("ui_cancel"):
		sponsor_popup.visible = false
