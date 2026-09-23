extends Node3D

const PLAYER_MODEL: PackedScene = preload("res://assets/models/robot_player.glb")
const ENEMY_MODEL: PackedScene = preload("res://assets/models/robot_enemy.glb")
const BOSS_MODEL: PackedScene = preload("res://assets/models/grim_reaper_boss.glb")

const ARENA_LIMIT := 12.0
const PLAYER_SPEED := 5.6
const DASH_SPEED := 14.0
const PLAYER_MAX_HP := 100.0
const PROJECTILE_SPEED := 13.0

var rng := RandomNumberGenerator.new()
var player: Node3D
var camera: Camera3D
var player_hp := PLAYER_MAX_HP
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var wave := 0
var kills := 0
var wave_pending := false
var wave_timer := 0.0
var boss_active := false
var game_over := false
var attack_cooldown := 0.0
var dash_cooldown := 0.0
var dash_timer := 0.0
var invulnerable := 0.0
var last_move := Vector2(0.0, -1.0)

var hp_bar: ProgressBar
var wave_label: Label
var kills_label: Label
var status_label: Label
var overlay: Control
var overlay_title: Label
var joystick_base: Panel
var joystick_knob: Panel
var joystick_id := -1
var joystick_origin := Vector2.ZERO
var joystick_value := Vector2.ZERO


func _ready() -> void:
	rng.randomize()
	_setup_input()
	_build_world()
	_spawn_player()
	_build_ui()
	_start_next_wave()


func _process(delta: float) -> void:
	if game_over:
		return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	invulnerable = maxf(0.0, invulnerable - delta)

	_update_player(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_camera(delta)

	if Input.is_action_just_pressed("attack"):
		_shoot()
	if Input.is_action_just_pressed("dash"):
		_try_dash()

	if wave_pending:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_pending = false
			_start_next_wave()

	_update_hud()


func _setup_input() -> void:
	var keys := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
		"attack": KEY_SPACE,
		"dash": KEY_SHIFT
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.keycode = keys[action]
		InputMap.action_add_event(action, event)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.28, 0.42)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.7
	sun.light_color = Color(0.78, 0.86, 1.0)
	sun.shadow_enabled = true
	add_child(sun)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 7.0, -5.0)
	rim.omni_range = 18.0
	rim.light_energy = 8.0
	rim.light_color = Color(0.35, 0.55, 1.0)
	add_child(rim)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28.0, 28.0)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.045, 0.055, 0.085)
	floor_mat.metallic = 0.55
	floor_mat.roughness = 0.58
	floor.material_override = floor_mat
	add_child(floor)

	for i in range(-6, 7):
		_add_grid_line(Vector3(float(i) * 2.0, 0.012, 0.0), Vector3(0.035, 0.02, 12.0))
		_add_grid_line(Vector3(0.0, 0.012, float(i) * 2.0), Vector3(12.0, 0.02, 0.035))

	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var p := Vector3(cos(angle) * 12.6, 0.8, sin(angle) * 12.6)
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.42, 1.6, 0.42)
		pillar.mesh = box
		pillar.position = p
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.11, 0.17)
		mat.emission_enabled = true
		mat.emission = Color(0.06, 0.18, 0.55)
		mat.emission_energy_multiplier = 1.8
		pillar.material_override = mat
		add_child(pillar)


func _add_grid_line(pos: Vector3, size: Vector3) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	line.mesh = mesh
	line.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.18, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(0.04, 0.15, 0.38)
	mat.emission_energy_multiplier = 1.1
	line.material_override = mat
	add_child(line)


func _spawn_player() -> void:
	player = Node3D.new()
	player.name = "Player"
	add_child(player)

	var model := PLAYER_MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.8
	player.add_child(model)

	var ring := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.64
	cylinder.bottom_radius = 0.64
	cylinder.height = 0.035
	ring.mesh = cylinder
	ring.position.y = 0.025
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.45, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.35, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	player.add_child(ring)

	camera = Camera3D.new()
	camera.fov = 53.0
	camera.position = Vector3(0.0, 14.5, 11.5)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _update_player(delta: float) -> void:
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := joystick_value if joystick_value.length() > 0.05 else kb
	if move.length() > 1.0:
		move = move.normalized()
	if move.length() > 0.05:
		last_move = move.normalized()

	var speed := DASH_SPEED if dash_timer > 0.0 else PLAYER_SPEED
	var delta_pos := Vector3(move.x, 0.0, move.y) * speed * delta
	player.position += delta_pos
	player.position.x = clampf(player.position.x, -ARENA_LIMIT, ARENA_LIMIT)
	player.position.z = clampf(player.position.z, -ARENA_LIMIT, ARENA_LIMIT)

	if move.length() > 0.08:
		var look_target := player.global_position + Vector3(move.x, 0.0, move.y)
		player.look_at(look_target, Vector3.UP)


func _try_dash() -> void:
	if dash_cooldown > 0.0 or game_over:
		return
	dash_cooldown = 1.25
	dash_timer = 0.22
	invulnerable = 0.30


func _shoot() -> void:
	if attack_cooldown > 0.0 or enemies.is_empty() or game_over:
		return
	var target := _nearest_enemy()
	if target.is_empty():
		return
	attack_cooldown = 0.30
	var target_node := target["node"] as Node3D
	var origin := player.global_position + Vector3(0.0, 0.75, 0.0)
	var direction := (target_node.global_position + Vector3(0.0, 0.65, 0.0) - origin).normalized()
	_spawn_projectile(origin, direction * PROJECTILE_SPEED, 28.0, false)


func _spawn_projectile(origin: Vector3, velocity: Vector3, damage: float, hostile: bool) -> void:
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13 if not hostile else 0.16
	sphere.height = sphere.radius * 2.0
	body.mesh = sphere
	body.position = origin
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.75, 1.0) if not hostile else Color(0.9, 0.12, 0.35)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 3.5
	body.material_override = mat
	add_child(body)
	projectiles.append({
		"node": body,
		"velocity": velocity,
		"damage": damage,
		"hostile": hostile,
		"life": 3.0
	})


func _update_projectiles(delta: float) -> void:
	for p in projectiles.duplicate():
		var node := p["node"] as Node3D
		if not is_instance_valid(node):
			projectiles.erase(p)
			continue
		p["life"] = float(p["life"]) - delta
		node.position += (p["velocity"] as Vector3) * delta

		if float(p["life"]) <= 0.0:
			_remove_projectile(p)
			continue

		if bool(p["hostile"]):
			if node.global_position.distance_to(player.global_position + Vector3(0.0, 0.6, 0.0)) < 0.75:
				_damage_player(float(p["damage"]))
				_remove_projectile(p)
		else:
			for enemy in enemies.duplicate():
				var enemy_node := enemy["node"] as Node3D
				if is_instance_valid(enemy_node) and node.global_position.distance_to(enemy_node.global_position + Vector3(0.0, 0.65, 0.0)) < 0.85:
					_damage_enemy(enemy, float(p["damage"]))
					_remove_projectile(p)
					break


func _remove_projectile(p: Dictionary) -> void:
	if not projectiles.has(p):
		return
	var node := p["node"] as Node3D
	projectiles.erase(p)
	if is_instance_valid(node):
		node.queue_free()


func _start_next_wave() -> void:
	wave += 1
	if wave <= 3:
		status_label.text = "DALGA %d" % wave
		var count := 3 + wave * 2
		for i in range(count):
			_spawn_enemy(false, i, count)
	else:
		boss_active = true
		status_label.text = "GRIM REAPER"
		_spawn_enemy(true, 0, 1)


func _spawn_enemy(is_boss: bool, index: int, count: int) -> void:
	var unit := Node3D.new()
	var angle := TAU * float(index) / maxf(float(count), 1.0) + rng.randf_range(-0.22, 0.22)
	var radius := rng.randf_range(8.5, 11.0)
	unit.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	add_child(unit)

	var model := (BOSS_MODEL if is_boss else ENEMY_MODEL).instantiate() as Node3D
	model.scale = Vector3.ONE * (2.7 if is_boss else 1.8)
	unit.add_child(model)

	var hp := 560.0 if is_boss else 70.0 + float(wave - 1) * 16.0
	enemies.append({
		"node": unit,
		"hp": hp,
		"max_hp": hp,
		"boss": is_boss,
		"hit_cd": rng.randf_range(0.0, 0.4),
		"shoot_cd": 0.8
	})


func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		var node := enemy["node"] as Node3D
		if not is_instance_valid(node):
			enemies.erase(enemy)
			continue

		enemy["hit_cd"] = maxf(0.0, float(enemy["hit_cd"]) - delta)
		enemy["shoot_cd"] = maxf(0.0, float(enemy["shoot_cd"]) - delta)

		var offset := player.global_position - node.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.05:
			node.look_at(player.global_position, Vector3.UP)

		var is_boss := bool(enemy["boss"])
		var stop_range := 3.5 if is_boss else 1.05
		if distance > stop_range:
			var enemy_speed := 2.25 if is_boss else 2.1 + float(wave) * 0.15
			node.position += offset.normalized() * enemy_speed * delta

		if not is_boss and distance < 1.25 and float(enemy["hit_cd"]) <= 0.0:
			enemy["hit_cd"] = 0.8
			_damage_player(10.0 + float(wave) * 1.5)

		if is_boss:
			if distance < 1.65 and float(enemy["hit_cd"]) <= 0.0:
				enemy["hit_cd"] = 0.7
				_damage_player(18.0)
			if float(enemy["shoot_cd"]) <= 0.0:
				enemy["shoot_cd"] = 1.15
				var origin := node.global_position + Vector3(0.0, 1.1, 0.0)
				var dir := (player.global_position + Vector3(0.0, 0.6, 0.0) - origin).normalized()
				_spawn_projectile(origin, dir * 8.2, 14.0, true)


func _nearest_enemy() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for enemy in enemies:
		var node := enemy["node"] as Node3D
		if is_instance_valid(node):
			var d := player.global_position.distance_squared_to(node.global_position)
			if d < best_distance:
				best_distance = d
				best = enemy
	return best


func _damage_enemy(enemy: Dictionary, amount: float) -> void:
	if not enemies.has(enemy):
		return
	enemy["hp"] = float(enemy["hp"]) - amount
	var node := enemy["node"] as Node3D
	_spawn_hit(node.global_position + Vector3(0.0, 0.7, 0.0), bool(enemy["boss"]))
	if float(enemy["hp"]) <= 0.0:
		_kill_enemy(enemy)


func _kill_enemy(enemy: Dictionary) -> void:
	if not enemies.has(enemy):
		return
	var was_boss := bool(enemy["boss"])
	var node := enemy["node"] as Node3D
	enemies.erase(enemy)
	kills += 1
	if is_instance_valid(node):
		_spawn_hit(node.global_position + Vector3(0.0, 0.7, 0.0), true)
		node.queue_free()

	if enemies.is_empty():
		if was_boss or boss_active:
			_finish_game(true)
		elif wave <= 3:
			wave_pending = true
			wave_timer = 1.25
			status_label.text = "ALAN TEMİZ"


func _damage_player(amount: float) -> void:
	if invulnerable > 0.0 or game_over:
		return
	player_hp = maxf(0.0, player_hp - amount)
	invulnerable = 0.18
	if player_hp <= 0.0:
		_finish_game(false)


func _spawn_hit(pos: Vector3, strong: bool) -> void:
	var burst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.23 if not strong else 0.38
	mesh.height = mesh.radius * 2.0
	burst.mesh = mesh
	burst.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 1.0) if not strong else Color(0.95, 0.2, 0.35)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 4.0
	burst.material_override = mat
	add_child(burst)
	var tween := create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.4, 0.22)
	tween.tween_callback(burst.queue_free)


func _finish_game(win: bool) -> void:
	game_over = true
	overlay.visible = true
	overlay_title.text = "PROTOKOL TAMAMLANDI" if win else "SİNYAL KAYBEDİLDİ"
	status_label.text = "ZAFER" if win else "YENİLDİN"


func _update_camera(delta: float) -> void:
	var target_pos := player.global_position + Vector3(0.0, 14.5, 11.5)
	camera.global_position = camera.global_position.lerp(target_pos, minf(1.0, delta * 4.2))
	camera.look_at(player.global_position + Vector3(0.0, 0.2, 0.0), Vector3.UP)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var top := Panel.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 86.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.015, 0.02, 0.04, 0.86)
	top_style.border_color = Color(0.12, 0.3, 0.55, 0.8)
	top_style.set_border_width_all(1)
	top.add_theme_stylebox_override("panel", top_style)
	canvas.add_child(top)

	var title := Label.new()
	title.text = "REAPER PROTOCOL"
	title.position = Vector2(24, 12)
	title.add_theme_font_size_override("font_size", 22)
	top.add_child(title)

	wave_label = Label.new()
	wave_label.position = Vector2(24, 47)
	wave_label.add_theme_font_size_override("font_size", 15)
	top.add_child(wave_label)

	kills_label = Label.new()
	kills_label.position = Vector2(185, 47)
	kills_label.add_theme_font_size_override("font_size", 15)
	top.add_child(kills_label)

	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(-90, 19)
	status_label.size = Vector2(180, 36)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	top.add_child(status_label)

	hp_bar = ProgressBar.new()
	hp_bar.max_value = PLAYER_MAX_HP
	hp_bar.value = PLAYER_MAX_HP
	hp_bar.show_percentage = false
	hp_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hp_bar.position = Vector2(-270, 24)
	hp_bar.size = Vector2(240, 24)
	top.add_child(hp_bar)

	var hp_text := Label.new()
	hp_text.text = "ENERJİ"
	hp_text.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hp_text.position = Vector2(-270, 52)
	hp_text.size = Vector2(240, 22)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_text.add_theme_font_size_override("font_size", 13)
	top.add_child(hp_text)

	joystick_base = Panel.new()
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.position = Vector2(38, -184)
	joystick_base.size = Vector2(142, 142)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var joy_style := StyleBoxFlat.new()
	joy_style.bg_color = Color(0.08, 0.12, 0.2, 0.58)
	joy_style.border_color = Color(0.22, 0.48, 0.82, 0.8)
	joy_style.set_border_width_all(2)
	joy_style.set_corner_radius_all(71)
	joystick_base.add_theme_stylebox_override("panel", joy_style)
	canvas.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.position = Vector2(43, 43)
	joystick_knob.size = Vector2(56, 56)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.25, 0.62, 1.0, 0.9)
	knob_style.set_corner_radius_all(28)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

	var fire := Button.new()
	fire.text = "ATEŞ"
	fire.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire.position = Vector2(-166, -160)
	fire.size = Vector2(124, 112)
	fire.add_theme_font_size_override("font_size", 22)
	fire.pressed.connect(_shoot)
	canvas.add_child(fire)

	var dash := Button.new()
	dash.text = "KAÇIN"
	dash.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash.position = Vector2(-302, -128)
	dash.size = Vector2(112, 80)
	dash.add_theme_font_size_override("font_size", 17)
	dash.pressed.connect(_try_dash)
	canvas.add_child(dash)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	canvas.add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.add_child(shade)

	overlay_title = Label.new()
	overlay_title.set_anchors_preset(Control.PRESET_CENTER)
	overlay_title.position = Vector2(-250, -65)
	overlay_title.size = Vector2(500, 55)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 30)
	overlay.add_child(overlay_title)

	var restart := Button.new()
	restart.text = "YENİDEN BAŞLAT"
	restart.set_anchors_preset(Control.PRESET_CENTER)
	restart.position = Vector2(-110, 15)
	restart.size = Vector2(220, 58)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	overlay.add_child(restart)


func _update_hud() -> void:
	hp_bar.value = player_hp
	wave_label.text = "DALGA: BOSS" if boss_active else "DALGA: %d / 3" % mini(wave, 3)
	kills_label.text = "İMHA: %d" % kills


func _input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and joystick_id == -1 and joystick_base.get_global_rect().has_point(touch.position):
			joystick_id = touch.index
			joystick_origin = joystick_base.get_global_rect().get_center()
			_set_joystick(touch.position)
		elif not touch.pressed and touch.index == joystick_id:
			joystick_id = -1
			joystick_value = Vector2.ZERO
			joystick_knob.position = Vector2(43, 43)

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_id:
			_set_joystick(drag.position)


func _set_joystick(screen_pos: Vector2) -> void:
	var delta := screen_pos - joystick_origin
	var radius := 52.0
	if delta.length() > radius:
		delta = delta.normalized() * radius
	joystick_value = delta / radius
	joystick_knob.position = Vector2(43, 43) + delta
