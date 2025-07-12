extends Node2D

#classes needed for menu logic
var shop: Shop
var auto_timer: Timer

var resources = {
	"effort":299,
	"manpower": 0,
	"think": 0,
	"materials": 0,
}
#initial values for multiplying later
var effort_press_strength_base := 1        # Base raw value
var effort_press_multiplier := 1.0         # Cumulative multiplier 
var effort_press_bonus := 0                # Additive bonuses or prestige bonuses

var manpower_strength = 1
var fire_unlocked = false
var active_configs = []
var autoclick_enabled := false

var shop_configs = {} #Loads from JSON file

var resource_labels = {}

func update_age(new_age: String):
	active_configs.clear()
	
	for key in shop_configs.keys():
		var config = shop_configs[key]
		if config["age"] == new_age:
			if config.has("unlock_effort"):
				if resources["effort"] >= config["unlock_effort"]:
					active_configs.append(config)
			else:
				active_configs.append(config)
	shop.update_buttons(active_configs)

func update_all_labels() -> void:
	for key in resources.keys():
		resource_labels[key].text = "[b]" + key.capitalize() + ":[/b] " + str(resources[key])

func _on_auto_timer_timeout() -> void:
	if resources["manpower"] > 0:
		resources["effort"] += manpower_strength * resources["manpower"]
	
func get_current_click_power() -> int:
	return int((effort_press_strength_base + effort_press_bonus) * effort_press_multiplier)
	
func check_unlocks():
	for key in shop_configs.keys():
		var config = shop_configs[key]
		if config["age"] == "Stone Age":
			if config.has("unlock_key") and config.has("unlock_amount"):
				var unlock_key = config["unlock_key"]
				var unlock_amount = config["unlock_amount"]
				if config not in active_configs and resources[unlock_key] >= unlock_amount:
					active_configs.append(config)
			else:
				if config not in active_configs:
					active_configs.append(config)
	shop.update_buttons(active_configs)

func sanitize_json_numbers(data):
	if typeof(data) == TYPE_DICTIONARY:
		for key in data.keys():
			data[key] = sanitize_json_numbers(data[key])
		return data
	elif typeof(data) == TYPE_ARRAY:
		for i in range(data.size()):
			data[i] = sanitize_json_numbers(data[i])
		return data
	elif typeof(data) == TYPE_FLOAT and int(data) == data:
		return int(data)
	else:
		return data

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	#--------------------------------------------------------------------------
	#variable block, we set up most hardcoded variables here
	#--------------------------------------------------------------------------
	var start_x = 50
	var start_y = 100
	var spacing_x = 40
	var spacing_y = 0
	var i = 0
	#--------------------------------------------------------------------------
	#Loading configs from JSON files
	#--------------------------------------------------------------------------
	var file = FileAccess.open("res://config/shop_config.json", FileAccess.READ)
	var data = file.get_as_text()
	var json = JSON.parse_string(data)
	if json != null:
		shop_configs = sanitize_json_numbers(json)
	else:
		print("Error parsing JSON")
	file.close()
	#--------------------------------------------------------------------------
	#Class variables are created and initialized here
	#--------------------------------------------------------------------------
	
	#The Shop
	shop = Shop.new(self)
	add_child(shop)
	update_age("Stone Age")
	
	#Producer timers
	auto_timer = Timer.new()
	auto_timer.wait_time = 0.5    #TODO: stop hardcoding in, needs scaling capabilities
	auto_timer.one_shot = false
	auto_timer.autostart = false
	auto_timer.stop()
	print("On ready, is timer stopped? ", auto_timer.is_stopped())
	add_child(auto_timer)
	auto_timer.timeout.connect(_on_auto_timer_timeout)
	

#creating pure display labels for the various resources/currencies
	for key in resources:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true 
		label.text = "[b]" + key.capitalize() + ":[/b] 0"
		label.size = Vector2(180, 30)
		label.position = Vector2(start_x + label.size.x * i + i * spacing_x, start_y + i * spacing_y)
		
		add_child(label)
		resource_labels[key] = label
		i += 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_all_labels()
