extends Node

class_name Shop

var current_age: String = "Stone Age"
var buttons := []
var button_dict := {}
var main_node
#variables for shop logic


func _init(p_main_node = null):
	main_node = p_main_node


func add_button(button: Button, config: Dictionary):
	#TODO: This needs modularity, monster code ahead
	
	buttons.append(button)
	add_child(button)
	button.visible = false
	button.size = Vector2(180, 30)
	if config.has("cooldown_time") and button.has_method("set_cooldown_time"):
		button.set_cooldown_time(config["cooldown_time"])

	
	button.pressed.connect(func():
		
		
		print("Pressed:", button.text)
		
		var cost_key = config.get("cost_key", null)
		var reward_key = config.get("reward_key", null)
		var cost_amount = config.get("cost_amount", 0)
		var reward_amount = config.get("reward_amount", 0)
		var cost_scale = config.get("cost_scale", 1.0)
		
		
		
		if main_node != null:
			
			if main_node.resources[cost_key] >=cost_amount:
				main_node.resources[cost_key] -= cost_amount
				# Sanity checker
				if main_node.resources[cost_key] < 0:
					main_node.resources[cost_key] = 0
				if config.has("reward_key") and config["reward_key"] != null:
					main_node.resources[reward_key] += reward_amount
					print("New cost for ", reward_key, ": ", config["cost_amount"])
				# Scale cost for next purchase
				var new_cost = cost_amount
				if config.has("scaling_type"):
					match config["scaling_type"]:
						"exponential":
							new_cost = int(cost_amount * cost_scale)
						"logarithmic":
							new_cost = int(cost_amount + log(cost_amount + 1) * 5)
				else:
					new_cost = int(cost_amount * cost_scale)
				config["cost_amount"] = new_cost
				print("New cost for ", reward_key, ": ", config["cost_amount"])
				
				if reward_key == "manpower":
					main_node.resource_labels["manpower"].visible = true
					if main_node.auto_timer.is_stopped():
						main_node.auto_timer.start()
			else:
				print("Not enough ", cost_key, " to buy!")
				return
			
			if config.has("effect"):
				match config["effect"]:
					"increase_click_bonus":
						main_node.effort_press_bonus += config["bonus_amount"]
						print("Click bonus increased by ", config["bonus_amount"])
						main_node.fire_unlocked = true
				# Flag: can be used for future UI or tech tree unlock checks
						button.disabled = true
					"enable_autoclick":
						main_node.autoclick_enabled = true
						print("Autoclick feature enabled!")
						button.disabled = true

		)

func update_buttons(config_list: Array):
	# Create new buttons from configs
	for config in config_list:
		var key = config.get("button_label", "unknown")
		if not button_dict.has(key):
			var b = Button.new()
			b.text = "Buy " + config.get("button_label", "Upgrade")
			var local_config = config.duplicate() #prevent shared reference issues
			add_button(b, local_config)
			button_dict[key] = {
				"button": b,
				"config": local_config,
				"unlocked": false
			}
			b.visible = false
		if config.has("unlock_key") and config.has("unlock_amount"):
			var unlock_key = config["unlock_key"]
			var unlock_amount = config["unlock_amount"]
			if main_node.resources[unlock_key] >= unlock_amount:
				button_dict[key]["unlocked"] = true
				button_dict[key]["button"].visible = true
		else:
				button_dict[key]["unlocked"] = true
				button_dict[key]["button"].visible = true

	position_buttons()

func position_buttons():
	var start_x = 50
	var start_y = ProjectSettings.get_setting("display/window/size/viewport_height") -150
	var spacing_x = 200
	var spacing_y = 0
	var button_array = []
	for value in button_dict.values():
		button_array.append(value["button"])
	
	for i in range(button_array.size()):
		button_array[i].position = Vector2(start_x + i * spacing_x, start_y + i * spacing_y)
		




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	pass
