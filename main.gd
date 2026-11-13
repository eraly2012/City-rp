extends Node3D

const SAVE_PATH := "user://city_rp_save.cfg"
var player_name := "Игрок"
var player_role := "Житель"
var coins := 5000
var owned_cars: Array[String] = ["Скутер"]
var owned_house := false
var active_panel: Control
var active_panel_layer: CanvasLayer
var player: CharacterBody3D
var camera: Camera3D
var coins_label: Label
var is_driving := false
var vehicle_locked := true
var vehicle_visual: MeshInstance3D
var mission_done := false
var npc_nodes: Array[Node3D] = []
var command_input: LineEdit
var chat_log: Label
var chat_lines: Array[String] = []

func _ready() -> void:
    _load_game()
    _build_world()
    _build_player()
    _build_ui()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.78, 0.88)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.1
    add_child(sun)

    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(180, 180)
    ground.mesh = plane
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.22, 0.42, 0.25)
    ground.material_override = ground_mat
    ground.position.y = -0.12
    add_child(ground)

    _add_road(Vector3(0, 0.01, 0), Vector3(100, 0.1, 12))
    _add_road(Vector3(0, 0.02, 0), Vector3(12, 0.1, 100))

    var buildings := [
        ["АДМИНИСТРАЦИЯ", Vector3(-22, 0, -20), Color(0.55,0.58,0.65)],
        ["БОЛЬНИЦА", Vector3(22, 0, -20), Color(0.78,0.82,0.84)],
        ["ПОЛИЦИЯ", Vector3(-22, 0, 20), Color(0.24,0.34,0.52)],
        ["АВТОСАЛОН", Vector3(22, 0, 20), Color(0.62,0.48,0.28)],
        ["МАГАЗИН", Vector3(-42, 0, 0), Color(0.55,0.42,0.3)],
        ["КАЗИНО", Vector3(42, 0, 0), Color(0.42,0.25,0.48)],
        ["МОЙ ДОМ", Vector3(0, 0, -42), Color(0.55,0.48,0.36)]
    ]
    for item in buildings:
        _add_building(item[0], item[1], item[2])

    for i in range(12):
        var tree := MeshInstance3D.new()
        var trunk := CylinderMesh.new()
        trunk.top_radius = 0.18
        trunk.bottom_radius = 0.25
        trunk.height = 2.0
        tree.mesh = trunk
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.35,0.22,0.12)
        tree.material_override = mat
        tree.position = Vector3(-55 + i * 10, 1, 48)
        add_child(tree)

    _add_npc("Таксист", Vector3(7, 1, 7), Color(0.9, 0.65, 0.15))
    _add_npc("Механик", Vector3(-8, 1, -7), Color(0.2, 0.7, 0.45))
    _add_npc("Медик", Vector3(25, 1, -12), Color(0.85, 0.85, 0.9))

func _add_npc(npc_name: String, pos: Vector3, color: Color) -> void:
    var npc := Node3D.new()
    npc.position = pos
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.48
    capsule.height = 1.8
    body.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    body.material_override = mat
    npc.add_child(body)
    var tag := Label3D.new()
    tag.text = npc_name
    tag.font_size = 32
    tag.position = Vector3(0, 1.5, 0)
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    npc.add_child(tag)
    add_child(npc)
    npc_nodes.append(npc)

func _add_road(pos: Vector3, size: Vector3) -> void:
    var road := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    road.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.12,0.13,0.15)
    road.material_override = mat
    road.position = pos
    add_child(road)

func _add_building(label: String, pos: Vector3, color: Color) -> void:
    var body := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(12, 7, 10)
    body.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    body.material_override = mat
    body.position = pos + Vector3(0, 3.5, 0)
    add_child(body)

    var sign := Label3D.new()
    sign.text = label
    sign.font_size = 42
    sign.position = pos + Vector3(0, 8, 0)
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.modulate = Color.WHITE
    add_child(sign)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.55
    shape.height = 2.0
    capsule.shape = shape
    player.add_child(capsule)

    var visual := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.55
    mesh.height = 2.0
    visual.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.2,0.55,0.9)
    visual.material_override = mat
    player.add_child(visual)
    player.position = Vector3(0, 1, 5)
    add_child(player)

    camera = Camera3D.new()
    camera.position = Vector3(0, 8, 13)
    camera.rotation_degrees = Vector3(-25, 0, 0)
    player.add_child(camera)
    camera.current = true

func _physics_process(delta: float) -> void:
    if player == null:
        return
    var input := Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"): input.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"): input.y += 1
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"): input.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"): input.x += 1
    if input.length() > 0:
        var dir := Vector3(input.x, 0, input.y).normalized()
        var move_speed := 13.0 if is_driving else 7.0
        player.velocity.x = dir.x * move_speed
        player.velocity.z = dir.z * move_speed
    else:
        player.velocity.x = move_toward(player.velocity.x, 0, 24 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0, 24 * delta)
    player.velocity.y -= 20.0 * delta
    player.move_and_slide()
    if is_instance_valid(vehicle_visual):
        vehicle_visual.global_position = player.global_position + Vector3(0, -0.45, 0)
        vehicle_visual.rotation.y = player.rotation.y
    if is_driving and player.velocity.length() > 0.2:
        player.rotation.y = atan2(-player.velocity.x, -player.velocity.z)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)

    var top := PanelContainer.new()
    top.position = Vector2(18, 16)
    top.custom_minimum_size = Vector2(300, 84)
    root.add_child(top)
    var top_col := VBoxContainer.new()
    top.add_child(top_col)
    var name_label := Label.new()
    name_label.text = player_name + " • " + player_role
    top_col.add_child(name_label)
    coins_label = Label.new()
    top_col.add_child(coins_label)
    _refresh_coins()

    var menu := VBoxContainer.new()
    menu.position = Vector2(18, 120)
    menu.add_theme_constant_override("separation", 8)
    root.add_child(menu)
    _add_button(menu, "Персонаж", _show_character)
    _add_button(menu, "Гараж", _show_garage)
    _add_button(menu, "Автосалон", _show_dealership)
    _add_button(menu, "Недвижимость", _show_house)
    _add_button(menu, "Задания и NPC", _show_missions)
    _add_button(menu, "Сесть / выйти из машины", _toggle_vehicle)
    _add_button(menu, "Работа", _work_bonus)
    _add_button(menu, "Сохранить", _save_game)

    var help := Label.new()
    help.text = "Управление: WASD или стрелки"
    help.position = Vector2(18, 680)
    root.add_child(help)

    var chat_panel := PanelContainer.new()
    chat_panel.position = Vector2(390, 455)
    chat_panel.custom_minimum_size = Vector2(500, 190)
    root.add_child(chat_panel)
    var chat_col := VBoxContainer.new()
    chat_panel.add_child(chat_col)
    var chat_title := Label.new()
    chat_title.text = "Чат и команды"
    chat_col.add_child(chat_title)
    chat_log = Label.new()
    chat_log.text = "Введи /help, чтобы увидеть команды."
    chat_log.custom_minimum_size = Vector2(470, 115)
    chat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    chat_col.add_child(chat_log)
    var command_row := HBoxContainer.new()
    chat_col.add_child(command_row)
    command_input = LineEdit.new()
    command_input.placeholder_text = "Введите команду, например /help"
    command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    command_row.add_child(command_input)
    command_input.text_submitted.connect(_on_command_submitted)
    var send_button := Button.new()
    send_button.text = "Отправить"
    command_row.add_child(send_button)
    send_button.pressed.connect(func(): _on_command_submitted(command_input.text))

    var touch := HBoxContainer.new()
    touch.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    touch.position = Vector2(-300, -150)
    touch.size = Vector2(280, 120)
    touch.add_theme_constant_override("separation", 12)
    root.add_child(touch)
    for key in ["←", "↑", "↓", "→"]:
        var b := Button.new()
        b.text = key
        b.custom_minimum_size = Vector2(60, 70)
        touch.add_child(b)
        b.button_down.connect(func(): _touch_key(key, true))
        b.button_up.connect(func(): _touch_key(key, false))

func _on_command_submitted(raw_text: String) -> void:
    var text_value := raw_text.strip_edges()
    if text_value.is_empty():
        return
    command_input.clear()
    if not text_value.begins_with("/"):
        _add_chat_line(player_name + ": " + text_value)
        return

    var parts := text_value.split(" ", false, 1)
    var command := str(parts[0]).to_lower()
    var argument := str(parts[1]).strip_edges() if parts.size() > 1 else ""

    match command:
        "/help":
            _add_chat_line("Команды: /me текст, /do текст, /stats, /balance, /id, /garage, /house, /car, /engine, /work")
        "/me":
            if argument.is_empty():
                _add_chat_line("Использование: /me действие")
            else:
                _add_chat_line("* " + player_name + " " + argument)
        "/do":
            if argument.is_empty():
                _add_chat_line("Использование: /do описание ситуации")
            else:
                _add_chat_line("[Действие] " + argument)
        "/stats":
            _add_chat_line("Персонаж: " + player_name + " | Роль: " + player_role + " | Деньги: $" + str(coins))
        "/balance":
            _add_chat_line("На счету: $" + str(coins))
        "/id":
            _add_chat_line("Ваш ID в офлайн-прототипе: 1")
        "/garage":
            _show_garage()
            _add_chat_line("Открыт гараж.")
        "/house":
            _show_house()
            _add_chat_line("Открыто меню недвижимости.")
        "/lk":
            if not is_instance_valid(vehicle_visual):
                _add_chat_line("Сначала выведи транспорт из гаража командой /car.")
            else:
                vehicle_locked = not vehicle_locked
                _add_chat_line("Транспорт " + ("закрыт." if vehicle_locked else "открыт."))
        "/car":
            if owned_cars.size() > 0:
                _spawn_vehicle(owned_cars[0])
                _add_chat_line("Машина выведена из гаража.")
            else:
                _add_chat_line("В гараже пока нет машин.")
        "/engine":
            _toggle_vehicle()
        "/work":
            _work_bonus()
            _add_chat_line("Вы выполнили работу и получили награду.")
        _:
            _add_chat_line("Неизвестная команда. Напиши /help.")

func _add_chat_line(line: String) -> void:
    chat_lines.append(line)
    while chat_lines.size() > 5:
        chat_lines.pop_front()
    if is_instance_valid(chat_log):
        chat_log.text = "\\n".join(chat_lines)

func _touch_key(key: String, pressed: bool) -> void:
    var code := {"←": KEY_A, "↑": KEY_W, "↓": KEY_S, "→": KEY_D}[key]
    var action_name := "ui_left" if code == KEY_A else "ui_up" if code == KEY_W else "ui_down" if code == KEY_S else "ui_right"
    if pressed:
        Input.action_press(action_name)
    else:
        Input.action_release(action_name)

func _add_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(190, 44)
    parent.add_child(b)
    b.pressed.connect(action)

func _show_panel(title_text: String) -> VBoxContainer:
    if is_instance_valid(active_panel_layer):
        active_panel_layer.queue_free()
    var panel := PanelContainer.new()
    panel.position = Vector2(235, 110)
    panel.custom_minimum_size = Vector2(390, 430)
    var layer := CanvasLayer.new()
    add_child(layer)
    layer.add_child(panel)
    active_panel_layer = layer
    active_panel = panel
    var col := VBoxContainer.new()
    panel.add_child(col)
    var title := Label.new()
    title.text = title_text
    title.add_theme_font_size_override("font_size", 24)
    col.add_child(title)
    return col

func _panel_button(col: VBoxContainer, caption: String, action: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 44)
    col.add_child(b)
    b.pressed.connect(action)

func _show_character() -> void:
    var col := _show_panel("Персонаж")
    _panel_button(col, "Имя: " + player_name, func(): pass)
    _panel_button(col, "Роль: " + player_role, func(): pass)
    _panel_button(col, "Баланс: $" + str(coins), func(): pass)
    _panel_button(col, "Закрыть", _close_panel)

func _show_garage() -> void:
    var col := _show_panel("Гараж")
    for car in owned_cars:
        _panel_button(col, "🚗 " + car, func(): _spawn_vehicle(car))
    _panel_button(col, "Вывести выбранную машину", func(): _spawn_vehicle(owned_cars[0] if owned_cars.size() > 0 else "Скутер"))
    _panel_button(col, "Закрыть", _close_panel)

func _show_dealership() -> void:
    var col := _show_panel("Автосалон")
    _panel_button(col, "Купить Седан — $2 000", func(): _buy_car("Седан", 2000))
    _panel_button(col, "Купить Внедорожник — $4 000", func(): _buy_car("Внедорожник", 4000))
    _panel_button(col, "Купить Спорткар — $8 000", func(): _buy_car("Спорткар", 8000))
    _panel_button(col, "Закрыть", _close_panel)

func _buy_car(car: String, price: int) -> void:
    if car in owned_cars:
        _show_message("Эта машина уже есть в гараже")
    elif coins >= price:
        coins -= price
        owned_cars.append(car)
        _save_game()
        _refresh_coins()
        _show_dealership()
    else:
        _show_message("Недостаточно денег")

func _show_house() -> void:
    var col := _show_panel("Недвижимость")
    if owned_house:
        _panel_button(col, "У вас уже есть дом", func(): pass)
    else:
        _panel_button(col, "Купить небольшой дом — $3 000", _buy_house)
    _panel_button(col, "Закрыть", _close_panel)

func _buy_house() -> void:
    if owned_house:
        return
    if coins >= 3000:
        coins -= 3000
        owned_house = true
        _save_game()
        _refresh_coins()
        _show_house()
    else:
        _show_message("Недостаточно денег")

func _spawn_vehicle(car_name: String) -> void:
    _close_panel()
    if is_instance_valid(vehicle_visual):
        vehicle_visual.queue_free()
    vehicle_visual = MeshInstance3D.new()
    var body := BoxMesh.new()
    body.size = Vector3(2.2, 0.9, 4.0)
    vehicle_visual.mesh = body
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.85, 0.2, 0.12) if car_name != "Скутер" else Color(0.2, 0.6, 0.9)
    vehicle_visual.material_override = mat
    vehicle_visual.position = player.position + Vector3(0, -0.45, -2.5)
    vehicle_locked = true
    is_driving = false
    player.get_child(1).visible = true
    add_child(vehicle_visual)
    _show_message(car_name + " готова. Нажми «Сесть / выйти из машины».")

func _toggle_vehicle() -> void:
    if not is_instance_valid(vehicle_visual):
        _show_message("Сначала выведи машину из гаража")
        return
    if vehicle_locked:
        _show_message("Транспорт закрыт. Открой его командой /lk")
        return
    is_driving = not is_driving
    player.get_child(1).visible = not is_driving
    _show_message("Вы за рулём" if is_driving else "Вы вышли из машины")

func _show_missions() -> void:
    var col := _show_panel("Задания и NPC")
    var intro := Label.new()
    intro.text = "В городе есть таксист, механик и медик.\nПодойди к NPC и выполни учебное поручение."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(intro)
    if mission_done:
        _panel_button(col, "Поручение выполнено: +$750 получено", func(): pass)
    else:
        _panel_button(col, "Выполнить поручение таксиста (+$750)", _complete_mission)
    _panel_button(col, "Закрыть", _close_panel)

func _complete_mission() -> void:
    if mission_done:
        return
    mission_done = true
    coins += 750
    _save_game_silent()
    _refresh_coins()
    _show_message("Поручение выполнено! Вы получили $750.")

func _save_game_silent() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("player", "name", player_name)
    cfg.set_value("player", "role", player_role)
    cfg.set_value("player", "coins", coins)
    cfg.set_value("garage", "cars", owned_cars)
    cfg.set_value("property", "has_house", owned_house)
    cfg.set_value("missions", "mission_done", mission_done)
    cfg.save(SAVE_PATH)

func _work_bonus() -> void:
    coins += 500
    _save_game()
    _refresh_coins()
    _show_message("Вы заработали $500")

func _show_message(message: String) -> void:
    var col := _show_panel("Сообщение")
    var label := Label.new()
    label.text = message
    col.add_child(label)
    _panel_button(col, "ОК", _close_panel)

func _close_panel() -> void:
    if is_instance_valid(active_panel_layer):
        active_panel_layer.queue_free()
    active_panel = null
    active_panel_layer = null

func _refresh_coins() -> void:
    if is_instance_valid(coins_label):
        coins_label.text = "Баланс: $" + str(coins)

func _save_game() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("player", "name", player_name)
    cfg.set_value("player", "role", player_role)
    cfg.set_value("player", "coins", coins)
    cfg.set_value("garage", "cars", owned_cars)
    cfg.set_value("property", "has_house", owned_house)
    cfg.set_value("missions", "mission_done", mission_done)
    cfg.save(SAVE_PATH)
    _show_message("Прогресс сохранён на устройстве")

func _load_game() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        player_name = str(cfg.get_value("player", "name", player_name))
        player_role = str(cfg.get_value("player", "role", player_role))
        coins = int(cfg.get_value("player", "coins", coins))
        owned_cars = cfg.get_value("garage", "cars", owned_cars)
        owned_house = bool(cfg.get_value("property", "has_house", false))
        mission_done = bool(cfg.get_value("missions", "mission_done", false))
