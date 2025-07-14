extends Button

@export var main_node: Node2D

var cooldown_bar: ProgressBar

var hold_timer: Timer
var click_cooldown_timer: Timer
var can_click := true

func setup_from_config(config: Dictionary):
	# Set size
	if config.has("button_width") and config.has("button_height"):
		custom_minimum_size = Vector2(config["button_width"], config["button_height"])

	# Set color
	if config.has("button_color"):
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(config["button_color"])

		var new_theme = Theme.new()
		new_theme.set_stylebox("normal", "Button", stylebox)
		new_theme.set_stylebox("hover", "Button", stylebox)
		new_theme.set_stylebox("pressed", "Button", stylebox)

		self.theme = new_theme

	# Set cooldown
	if config.has("cooldown_time"):
		set_cooldown_time(config["cooldown_time"])

func _click_once():
	if main_node:
		main_node.resources["effort"] += main_node.get_current_click_power()
		print("Work pressed! Current effort:", main_node.resources["effort"])
		main_node.check_unlocks()
	else:
		print("Click ignored: no main_node")

func _on_button_down():
	if can_click:
		_click_once()
		can_click = false
		click_cooldown_timer.start()
		print("Manual button down")
		if main_node.autoclick_enabled and hold_timer.is_stopped():
			hold_timer.start()
			print("Starting hold timer (autoclick active)")
	else:
		print("Click ignored: cooldown active")

func _on_button_up():
	if not hold_timer.is_stopped():
		hold_timer.stop()
		print("Button released: stopping hold timer")

func _on_hold_timer_timeout():
	if hold_timer.is_stopped():
		return
	if can_click and is_pressed():
		_click_once()
	else:
		print("Hold ignored: either cooldown active or button not held")



func _on_cooldown_timeout():
	can_click = true
	print("Cooldown finished, can_click now true")
	# Immediately retrigger autoclick if active
	if main_node.autoclick_enabled and hold_timer.is_stopped():
		hold_timer.start()

func set_cooldown_time(seconds: float):
	click_cooldown_timer.wait_time = seconds

func _ready():
	connect("button_down", Callable(self, "_on_button_down"))
	connect("button_up", Callable(self, "_on_button_up"))

	hold_timer = Timer.new()
	hold_timer.wait_time = 0.5
	hold_timer.one_shot = false
	hold_timer.autostart = false
	add_child(hold_timer)
	hold_timer.timeout.connect(_on_hold_timer_timeout)

	click_cooldown_timer = Timer.new()
	click_cooldown_timer.wait_time = 0.5
	click_cooldown_timer.one_shot = true
	click_cooldown_timer.autostart = false
	add_child(click_cooldown_timer)
	click_cooldown_timer.timeout.connect(_on_cooldown_timeout)

	cooldown_bar = ProgressBar.new()
	cooldown_bar.min_value = 0
	cooldown_bar.max_value = click_cooldown_timer.wait_time
	cooldown_bar.value = 0
	cooldown_bar.anchor_left = 0
	cooldown_bar.anchor_right = 1
	cooldown_bar.anchor_top = 0
	cooldown_bar.anchor_bottom = 1
	#cooldown_bar.fill_mode = ProgressBar.FILL_LEFT_TO_RIGHT # 
	cooldown_bar.modulate = Color(0.2, 0.8, 0.2, 0.5)
	cooldown_bar.show_percentage = false
	cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cooldown_bar)

func _process(delta: float) -> void:
	
	# If holding (autoclick) and button is pressed
	if main_node.autoclick_enabled and is_pressed() and not hold_timer.is_stopped():
		cooldown_bar.max_value = hold_timer.wait_time
		cooldown_bar.value = hold_timer.wait_time - hold_timer.time_left
		# Else, show manual click cooldown
	elif not click_cooldown_timer.is_stopped():
		cooldown_bar.max_value = click_cooldown_timer.wait_time
		cooldown_bar.value = click_cooldown_timer.wait_time - click_cooldown_timer.time_left
	else:
		cooldown_bar.value = 0
