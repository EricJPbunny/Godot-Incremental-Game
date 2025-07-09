# WorkButton.gd
extends Button

@export var main_node: Node2D

var hold_timer: Timer

func _click_once():
	if main_node:
		main_node.resources["effort"] += main_node.get_current_click_power()
		print("Manual work pressed! Current effort:", main_node.resources["effort"])
		main_node.check_unlocks()
		print("Checked unlocks")

func _on_button_down():
	_click_once()
	print("Button down")
	if hold_timer.is_stopped():
		hold_timer.start()
		print("starting timer")

func _on_button_up():
	hold_timer.stop()
	print("Button released: stopping timer")

func _on_hold_timer_timeout():
	_click_once()


func _ready():
		#Autoclick timer
	connect("button_down", Callable(self, "_on_button_down"))
	connect("button_up", Callable(self, "_on_button_up"))
	hold_timer = Timer.new()
	hold_timer.wait_time = 0.1
	hold_timer.one_shot = false
	hold_timer.autostart = false
	add_child(hold_timer)
	hold_timer.timeout.connect(_on_hold_timer_timeout)
