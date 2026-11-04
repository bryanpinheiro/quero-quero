class_name DisplayModes
extends RefCounted
# DisplayModes — real display-mode switching via xrandr (Linux/X11).
#
# Godot's fullscreen modes only resize the window — the monitor keeps
# running at native resolution and the compositor upscales the big
# framebuffer every frame (~12ms at 1080p on this setup). Switching
# the REAL display mode makes the presentation buffer small, the
# PCSX2/Burnout-style trick: ~250fps at 720p real vs ~73 at 1080p.
#
# Non-Linux platforms have no portable real mode switching, so the
# selector is hidden and only the fullscreen toggle is exposed.
#
# Usage — three calls and a restore:
#   var display := DisplayModes.new()
#   display.setup(option_button, get_window())   # _ready()
#   display.toggle_fullscreen(get_window(), option.selected)
#   display.set_mode_if_fullscreen(get_window(), index)
#   display.restore_native()                     # on clean quit

const NATIVE_MODE := "1920x1080"   # your monitor's native mode
const FALLBACK_OUTPUT := "eDP"
const FALLBACK_MODE := "640x480"

var _screen_output := ""
var _modes := []   # [{name, w, h, wide}] sorted small → large


# ---------- public API ----------

# one-call init: on Linux fills the selector with the monitor's real
# modes; on other platforms the selector is hidden (no real mode
# switching there — the fullscreen button still works).
# Returns true when the selector is usable.
func setup(option: OptionButton, window: Window) -> bool:
	if not _is_supported():
		option.hide()
		return false
	_init_modes()
	_populate_option(option)
	# already launched fullscreen → apply the selected mode on boot
	if window.mode == Window.MODE_FULLSCREEN:
		set_mode(_mode_name(option.selected))
	return true


# button callback: toggles fullscreen, switching the real mode on Linux
func toggle_fullscreen(window: Window, mode_index: int) -> void:
	var to_full: bool = window.mode != Window.MODE_FULLSCREEN
	if _is_supported():
		set_mode(_mode_name(mode_index) if to_full else NATIVE_MODE)
	window.mode = Window.MODE_FULLSCREEN if to_full else Window.MODE_WINDOWED


# selector callback (Linux only): live-switch while fullscreen
func set_mode_if_fullscreen(window: Window, mode_index: int) -> void:
	if _is_supported() and window.mode == Window.MODE_FULLSCREEN:
		set_mode(_mode_name(mode_index))


# call on clean quit — if the game dies in a low-res mode this is the
# only thing that brings the monitor back (crashes skip it, though)
func restore_native() -> void:
	if _is_supported():
		set_mode(NATIVE_MODE)


# ---------- internals ----------

func _is_supported() -> bool:
	# real mode switch needs xrandr — Linux/X11 only
	return OS.get_name() == "Linux"


func _mode_name(index: int) -> String:
	return _modes[index].name if _modes.size() > index else FALLBACK_MODE


# switch the monitor to a mode NOW (fullscreen should already be on
# or about to be — the window fills whatever mode is active)
func set_mode(mode: String) -> void:
	if _screen_output != "":
		OS.execute("xrandr", ["--output", _screen_output, "--mode", mode])


func _init_modes() -> void:
	_screen_output = _find_output()
	_modes = _list_modes()


func _populate_option(option: OptionButton) -> void:
	for m in _modes:
		option.add_item("%s%s" % [m.name, " (16:9)" if m.wide else ""])
	option.selected = _default_index()


# preferred default: 800x600 (tiny + universally supported),
# else the first 16:9 mode, else the smallest mode
func _default_index() -> int:
	var default_i := 0
	var first_wide := -1
	for i in _modes.size():
		if _modes[i].name == "800x600":
			default_i = i
		elif _modes[i].wide and first_wide == -1:
			first_wide = i
	if default_i == 0 and first_wide != -1:
		default_i = first_wide
	return default_i


# the primary connected output (else first connected, else fallback)
func _find_output() -> String:
	var out: Array = []
	OS.execute("xrandr", ["--query"], out)
	for line in String(out[0]).split("\n"):
		if " connected" in line and "primary" in line:
			return line.split(" ")[0]
	for line in String(out[0]).split("\n"):
		if " connected" in line:
			return line.split(" ")[0]
	return FALLBACK_OUTPUT


# all modes the primary monitor accepts, small → large;
# "wide" marks ~16:9 modes for the selector label
func _list_modes() -> Array:
	var out: Array = []
	OS.execute("xrandr", ["--query"], out)
	var modes := []
	var in_primary := false
	for line in String(out[0]).split("\n"):
		if " connected" in line:
			in_primary = line.begins_with(_screen_output)
			continue
		if in_primary:
			if not line.begins_with("   "):
				break
			var mode := line.strip_edges().split(" ")[0]
			if "x" in mode:
				var wh := mode.split("x")
				var w := int(wh[0])
				var h := int(wh[1])
				modes.append({"w": w, "h": h, "name": mode,
					"wide": abs(float(w) / h - 1.778) < 0.05})
	modes.sort_custom(func(a, b): return a.w * a.h < b.w * b.h)
	return modes
