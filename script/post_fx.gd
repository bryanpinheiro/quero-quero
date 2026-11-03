extends CanvasLayer

@onready var cr_hit_feedback: ColorRect = $CR_HitFeedback
@onready var cr_speed_blur_2d: ColorRect = $CR_SpeedBlur2D

@onready var bbc_1: BackBufferCopy = $BBC1
@onready var bbc_2: BackBufferCopy = $BBC2
@onready var score_label: RichTextLabel = %ScoreLabel

const FX_RECTS := ["CR_HitFeedback", "CR_SpeedBlur2D", "CR_VHS_CRT"]
var _defaults := {}
var _shader_clock := 0.0

func _ready() -> void:
	save_defaults()
	cr_hit_feedback.visible = false
	cr_speed_blur_2d.visible = false
	bbc_1.visible = false
	bbc_2.visible = false
	score_label.visible = false
	
	
func _process(delta: float) -> void:
	_shader_clock += delta
	if cr_hit_feedback != null:
		cr_hit_feedback.material.set_shader_parameter("clock", _shader_clock)
 

func _update_bbcs() -> void:
	if bbc_1 == null or bbc_2 == null or cr_hit_feedback == null:
		return
	bbc_1.visible = cr_speed_blur_2d.visible and cr_hit_feedback.visible
	bbc_2.visible = (cr_hit_feedback.visible or cr_speed_blur_2d.visible)


func enable_juice(on: bool) -> void:
	if cr_hit_feedback == null or cr_speed_blur_2d == null:
		return
	cr_hit_feedback.visible = on
	cr_speed_blur_2d.visible = on
	score_label.visible = on 
	_update_bbcs()
 

func hit_feedback() -> void:
	if cr_hit_feedback == null:
		return
		
	cr_hit_feedback.visible = true
	cr_hit_feedback.material.set_shader_parameter("hit_time", _shader_clock)
	cr_hit_feedback.material.set_shader_parameter("pulses", 1)
	_update_bbcs()
 

func set_score(value: int) -> void:
	if score_label == null:
		return
	score_label.text = "[wave]%d[/wave]" % value
	

func set_speed_visible(on: bool) -> void:
	if cr_speed_blur_2d == null:
		return
	cr_speed_blur_2d.visible = on
	_update_bbcs()
	

func set_speed(intensity: float) -> void:
	if cr_speed_blur_2d == null:
		return
	var c := clampf(intensity, 0.0, 1.0)
	if c != intensity:
		push_warning("speed intensity %.2f fora do range 0–1" % intensity)
	cr_speed_blur_2d.material.set_shader_parameter("intensity", c)
 

func set_speed_length(v: float) -> void:
	if cr_speed_blur_2d == null:
		return
	var c := clampf(v, 0.0, 0.25)
	if c != v:
		push_warning("speed length %.2f fora do range 0–0.25" % v)
	cr_speed_blur_2d.material.set_shader_parameter("length", c)
 

func set_speed_streak_zone(v: float) -> void:
	if cr_speed_blur_2d == null:
		return
	var c := clampf(v, 0.0, 0.5)
	if c != v:
		push_warning("speed streak_zone %.2f fora do range 0–0.5" % v)
	cr_speed_blur_2d.material.set_shader_parameter("streak_zone", c)
 

func set_speed_flow(v: float) -> void:
	if cr_speed_blur_2d == null:
		return
	var c := clampf(v, 0.0, 20.0)
	if c != v:
		push_warning("speed flow_speed %.2f fora do range 0–20" % v)
	cr_speed_blur_2d.material.set_shader_parameter("flow_speed", c)
	
	
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
			
			
