extends CanvasLayer

@onready var cr_juice: ColorRect = $CR_Juice
@onready var score_label: RichTextLabel = %ScoreLabel

const FX_RECTS := ["CR_Juice", "CR_VHS_CRT"]
var _defaults := {}
var _shader_clock := 0.0
var _pulse_mode := 1


func _ready() -> void:
	save_defaults()
	score_label.visible = false


func _process(delta: float) -> void:
	_shader_clock += delta
	if cr_juice != null:
		cr_juice.material.set_shader_parameter("clock", _shader_clock)


func enable_juice(on: bool) -> void:
	if cr_juice == null:
		return
	score_label.visible = on


func hit_feedback() -> void:
	if cr_juice == null:
		return
	cr_juice.material.set_shader_parameter("hit_time", _shader_clock)


func pulse() -> void:
	if cr_juice == null:
		return
	cr_juice.material.set_shader_parameter("pulse_time", _shader_clock)
	cr_juice.material.set_shader_parameter("pulse_mode", _pulse_mode)

	var pace_name: String = MechanicsManager.pace_order[MechanicsManager.current_pace_index]
	var durations := {"warmup": 1.4, "moderate": 0.9, "fast": 0.6, "sprint": 0.35}
	cr_juice.material.set_shader_parameter("pulse_paint_duration",
		durations.get(pace_name, 0.35))
	_pulse_mode = 3 - _pulse_mode


func set_score(value: int) -> void:
	if score_label == null:
		return
	score_label.text = "[wave]%d[/wave]" % value


func set_speed_visible(on: bool) -> void:
	if cr_juice == null:
		return

	cr_juice.material.set_shader_parameter("speed_intensity", 1.0 if on else 0.0)


func set_speed(intensity: float) -> void:
	if cr_juice == null:
		return
	var c := clampf(intensity, 0.0, 1.0)
	if c != intensity:
		push_warning("speed intensity %.2f fora do range 0–1" % intensity)
	cr_juice.material.set_shader_parameter("speed_intensity", c)


func set_speed_length(v: float) -> void:
	if cr_juice == null:
		return
	var c := clampf(v, 0.0, 0.25)
	if c != v:
		push_warning("speed length %.2f fora do range 0–0.25" % v)
	cr_juice.material.set_shader_parameter("length", c)


func set_speed_streak_zone(v: float) -> void:
	if cr_juice == null:
		return
	var c := clampf(v, 0.0, 0.5)
	if c != v:
		push_warning("speed streak_zone %.2f fora do range 0–0.5" % v)
	cr_juice.material.set_shader_parameter("streak_zone", c)


func set_speed_flow(v: float) -> void:
	if cr_juice == null:
		return
	var c := clampf(v, 0.0, 20.0)
	if c != v:
		push_warning("speed flow_speed %.2f fora do range 0–20" % v)
	cr_juice.material.set_shader_parameter("flow_speed", c)


func save_defaults() -> void:
	for rect_name in FX_RECTS:
		var node := get_node_or_null(rect_name)
		if node == null or node.material == null:
			push_error("save_defaults: '%s' não existe ou não tem material" % rect_name)
			continue
		var material: ShaderMaterial = node.material
		_defaults[rect_name] = {}
		for u in material.shader.get_shader_uniform_list():
			_defaults[rect_name][u.name] = material.get_shader_parameter(u.name)


func reset_defaults(node_name: String = "") -> void:
	if _defaults.is_empty():
		save_defaults()
	var targets = _defaults.keys() if node_name == "" else [node_name]
	for rect_name in targets:
		if not _defaults.has(rect_name):
			push_warning("reset_defaults: '%s' não está no snapshot" % rect_name)
			continue
		var node := get_node_or_null(rect_name)
		if node == null or node.material == null:
			continue
		var material: ShaderMaterial = node.material
		for p in _defaults[rect_name]:
			material.set_shader_parameter(p, _defaults[rect_name][p])
