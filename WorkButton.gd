extends Button

@export var main_node: Node2D

# timers
var hold_timer: Timer
var click_cooldown_timer: Timer
var can_click := true

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
		print("Manual button down")
		can_click = false
		click_cooldown_timer.start()
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
	_click_once()

func _on_cooldown_timeout():
	can_click = true
	print("Cooldown finished, can_click now true")

func _ready():
	# Connect signals
	connect("button_down", Callable(self, "_on_button_down"))
	connect("button_up", Callable(self, "_on_button_up"))

	# Hold timer (for automation)
	hold_timer = Timer.new()
	hold_timer.wait_time = 0.5  # adjust as needed
	hold_timer.one_shot = false
	hold_timer.autostart = false
	add_child(hold_timer)
	hold_timer.timeout.connect(_on_hold_timer_timeout)

	# Cooldown timer for manual clicks
	click_cooldown_timer = Timer.new()
	click_cooldown_timer.wait_time = 0.5  # adjust as needed
	click_cooldown_timer.one_shot = true
	click_cooldown_timer.autostart = false
	add_child(click_cooldown_timer)
	click_cooldown_timer.timeout.connect(_on_cooldown_timeout)
