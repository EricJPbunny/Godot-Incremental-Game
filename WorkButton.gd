extends Button

# ===== CONSTANTS =====
# Color parsing
const DEFAULT_COLOR = Color.WHITE  # Fallback color for parsing errors

# ===== VARIABLES =====
@export var main_node: Node2D

var cooldown_bar: ProgressBar

var hold_timer: Timer
var click_cooldown_timer: Timer
var can_click := true

func parse_color(color_data) -> Color:
	if color_data is Array and color_data.size() >= 3:
		return Color(color_data[0], color_data[1], color_data[2])
	elif color_data is String:
		# Handle hex color strings like "#C68642"
		if color_data.begins_with("#"):
			var hex = color_data.substr(1)  # Remove the #
			if hex.length() == 6:
				var r = hex.substr(0, 2).hex_to_int() / 255.0
				var g = hex.substr(2, 2).hex_to_int() / 255.0
				var b = hex.substr(4, 2).hex_to_int() / 255.0
				return Color(r, g, b)
		# Try to parse as a named color
		return Color(color_data)
	else:
		print("WARNING: Unsupported color format: ", color_data)
		return DEFAULT_COLOR  # Default fallback

func setup_from_config(config: Dictionary):
	if not config:
		print("ERROR: Cannot setup work button with null config!")
		return
		
	# Set size
	if config.has("button_width") and config.has("button_height"):
		var width = config["button_width"]
		var height = config["button_height"]
		if width is int or width is float and height is int or height is float:
			custom_minimum_size = Vector2(width, height)
		else:
			print("WARNING: Invalid button dimensions in work button config: ", width, "x", height)

	# Set color
	if config.has("button_color"):
		var color_data = config["button_color"]
		var color = parse_color(color_data)
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = color

		var new_theme = Theme.new()
		new_theme.set_stylebox("normal", "Button", stylebox)
		new_theme.set_stylebox("hover", "Button", stylebox)
		new_theme.set_stylebox("pressed", "Button", stylebox)

		self.theme = new_theme

	# Set cooldown
	if config.has("cooldown_time"):
		var cooldown_time = config["cooldown_time"]
		if cooldown_time is float or cooldown_time is int:
			set_cooldown_time(cooldown_time)
		else:
			print("WARNING: Invalid cooldown_time format in work button config: ", cooldown_time)

func _click_once():
	if not main_node:
		print("ERROR: Click ignored: no main_node")
		return
		
	if not main_node.resources.has("effort"):
		print("ERROR: Main node missing effort resource!")
		return
		
	main_node.resources["effort"] += main_node.get_current_click_power()
	print("Work pressed! Current effort:", main_node.resources["effort"])
	main_node.total_clicks += 1

func _on_button_down():
	if not can_click:
		print("Click ignored: cooldown active")
		return
		
	_click_once()
	can_click = false
	if click_cooldown_timer:
		click_cooldown_timer.start()
	print("Manual button down")
	if main_node and main_node.autoclick_enabled and hold_timer and hold_timer.is_stopped():
		hold_timer.start()
		print("Starting hold timer (autoclick active)")

func _on_button_up():
	if hold_timer and not hold_timer.is_stopped():
		hold_timer.stop()
		print("Button released: stopping hold timer")

func _on_hold_timer_timeout():
	if not hold_timer or hold_timer.is_stopped():
		return
	if can_click and is_pressed():
		_click_once()
	else:
		print("Hold ignored: either cooldown active or button not held")

func _on_cooldown_timeout():
	can_click = true
	print("Cooldown finished, can_click now true")
	# Immediately retrigger autoclick if active
	if main_node and main_node.autoclick_enabled and hold_timer and hold_timer.is_stopped():
		hold_timer.start()

func set_cooldown_time(seconds: float):
	if not click_cooldown_timer:
		print("ERROR: Cannot set cooldown time - timer not initialized!")
		return
		
	if seconds < 0:
		print("WARNING: Negative cooldown time provided: ", seconds)
		seconds = 0
		
	click_cooldown_timer.wait_time = seconds

func _ready():
	if not has_signal("button_down"):
		print("ERROR: WorkButton missing button_down signal!")
		return
	if not has_signal("button_up"):
		print("ERROR: WorkButton missing button_up signal!")
		return
		
	connect("button_down", Callable(self, "_on_button_down"))
	connect("button_up", Callable(self, "_on_button_up"))

	hold_timer = Timer.new()
	if not hold_timer:
		print("ERROR: Failed to create hold timer!")
		return
	hold_timer.wait_time = 0.5
	hold_timer.one_shot = false
	hold_timer.autostart = false
	add_child(hold_timer)
	hold_timer.timeout.connect(_on_hold_timer_timeout)

	click_cooldown_timer = Timer.new()
	if not click_cooldown_timer:
		print("ERROR: Failed to create click cooldown timer!")
		return
	click_cooldown_timer.wait_time = 0.5
	click_cooldown_timer.one_shot = true
	click_cooldown_timer.autostart = false
	add_child(click_cooldown_timer)
	click_cooldown_timer.timeout.connect(_on_cooldown_timeout)

	cooldown_bar = ProgressBar.new()
	if not cooldown_bar:
		print("ERROR: Failed to create cooldown bar!")
		return
	cooldown_bar.min_value = 0
	cooldown_bar.max_value = click_cooldown_timer.wait_time
	cooldown_bar.value = 0
	cooldown_bar.anchor_left = 0
	cooldown_bar.anchor_right = 1
	cooldown_bar.anchor_top = 0
	cooldown_bar.anchor_bottom = 1
	cooldown_bar.modulate = Color(0.2, 0.8, 0.2, 0.5)
	cooldown_bar.show_percentage = false
	cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cooldown_bar)

func _process(delta: float) -> void:
	if not cooldown_bar:
		return
		
	# If holding (autoclick) and button is pressed
	if main_node and main_node.autoclick_enabled and is_pressed() and hold_timer and not hold_timer.is_stopped():
		cooldown_bar.max_value = hold_timer.wait_time
		cooldown_bar.value = hold_timer.wait_time - hold_timer.time_left
	# Else, show manual click cooldown
	elif click_cooldown_timer and not click_cooldown_timer.is_stopped():
		cooldown_bar.max_value = click_cooldown_timer.wait_time
		cooldown_bar.value = click_cooldown_timer.wait_time - click_cooldown_timer.time_left
	else:
		cooldown_bar.value = 0
