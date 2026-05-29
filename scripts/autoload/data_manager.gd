extends Node

var weapons: Dictionary = {}
var enemies: Dictionary = {}
var characters: Dictionary = {}
var upgrade_pool: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()

func _load_data() -> void:
	weapons["whip"] = {
		"id": "whip",
		"display_name": "鞭子",
		"description": "近距离横扫攻击",
		"base_damage": 15,
		"base_cooldown": 1.8,
		"base_range": 144.0,"projectile_speed": 0.0,
		"icon_color": Color(0.9, 0.7, 0.2)
	}
	weapons["magic_wand"] = {
		"id": "magic_wand",
		"display_name": "魔杖",
		"description": "发射追踪弹丸",
		"base_damage": 8,
		"base_cooldown": 1.2,
		"base_range": 600.0,
		"projectile_speed": 350.0,
		"icon_color": Color(0.3, 0.5, 1.0)
	}
	weapons["garlic"] = {
		"id": "garlic",
		"display_name": "大蒜",
		"description": "持续范围伤害光环",
		"base_damage": 3,
		"base_cooldown": 0.5,
		"base_range": 108.0,
		"projectile_speed": 0.0,
		"icon_color": Color(0.2, 0.9, 0.2)
	}
	weapons["thunder_rod"] = {
		"id": "thunder_rod",
		"display_name": "闪电权杖",
		"description": "弹跳链式闪电",
		"base_damage": 12,
		"base_cooldown": 1.6,
		"base_range": 500.0,
		"projectile_speed": 450.0,
		"icon_color": Color(1.0, 0.85, 0.1)
	}
	
	enemies["slime"] = {
		"id": "slime",
		"display_name": "史莱姆",
		"hp": 8,
		"speed": 40.0,
		"damage": 10,
		"exp_value": 5,
		"color": Color(0.2, 0.8, 0.3),
		"size": 14.0
	}
	
	enemies["ranged"] = {
		"id": "ranged",
		"display_name": "远程怪",
		"hp": 12,
		"speed": 50.0,
		"damage": 5,
		"exp_value": 7,
		"color": Color(0.8, 0.2, 0.2),
		"size": 20.0
	}
	enemies["charger"] = {
		"id": "charger",
		"display_name": "冲锋怪",
		"hp": 20,
		"speed": 60.0,
		"damage": 15,
		"exp_value": 10,
		"color": Color(0.9, 0.5, 0.15),
		"size": 18.0
	}
	enemies["bomber"] = {
		"id": "bomber",
		"display_name": "自爆兵",
		"hp": 12,
		"speed": 70.0,
		"damage": 20,
		"exp_value": 8,
		"color": Color(1.0, 0.2, 0.1),
		"size": 16.0
	}
	enemies["healer"] = {
		"id": "healer",
		"display_name": "治愈兵",
		"hp": 18,
		"speed": 45.0,
		"damage": 0,
		"exp_value": 15,
		"color": Color(1.0, 0.1, 0.1),
		"size": 18.0
	}
	
	characters["default"] = {
		"id": "default",
		"display_name": "默认角色",
		"max_hp": 100,
		"move_speed": 200.0,
		"starting_weapon": "magic_wand"
	}
	
	_build_upgrade_pool()

func get_weapon_data(id: String):
	return weapons.get(id)

func get_enemy_data(id: String):
	return enemies.get(id)

func get_character_data(id: String):
	return characters.get(id)

func _build_upgrade_pool() -> void:
	upgrade_pool.clear()
	
	for weapon_id in weapons:
		var wdata = weapons[weapon_id]
		upgrade_pool.append({
			"type": "weapon",
			"id": weapon_id,
			"name": wdata.display_name,
			"description": wdata.description,
			"icon_color": wdata.icon_color,
			"level": 1
		})
	
	upgrade_pool.append({
		"type": "stat",
		"id": "max_hp",
		"name": "最大生命 +20",
		"description": "+20 最大生命值",
		"icon_color": Color.GREEN,
		"value": 20
	})
	upgrade_pool.append({
		"type": "stat",
		"id": "move_speed",
		"name": "速度提升",
		"description": "+5% 移动速度",
		"icon_color": Color.CYAN,
		"value": 1.05
	})
	upgrade_pool.append({
		"type": "stat",
		"id": "range",
		"name": "范围提升",
		"description": "+10% 攻击范围",
		"icon_color": Color.DODGER_BLUE,
		"value": 1.1
	})
	upgrade_pool.append({
		"type": "stat",
		"id": "projectile_count",
		"name": "多重射击",
		"description": "+1 攻击数量",
		"icon_color": Color.ORANGE,
		"value": 1
	})
	upgrade_pool.append({
		"type": "stat",
		"id": "damage",
		"name": "力量提升",
		"description": "+15% 全伤害",
		"icon_color": Color.RED,
		"value": 1.15
	})
	upgrade_pool.append({
		"type": "stat",
		"id": "cooldown",
		"name": "急速",
		"description": "-10% 武器冷却",
		"icon_color": Color.YELLOW,
		"value": 0.9
	})

func get_random_upgrades(count: int = 3, player = null) -> Array:
	var available = upgrade_pool.duplicate(true)
	available.shuffle()
	
	if player:
		var filtered: Array = []
		var counts = player.upgrade_counts if "upgrade_counts" in player else {}
		for upgrade in available:
			var current_count = counts.get(upgrade.id, 0)
			if current_count >= 10:
				continue
			if upgrade.type == "weapon":
				upgrade.level = current_count + 1
			filtered.append(upgrade)
		available = filtered
	
	if available.size() <= count:
		return available
	
	return available.slice(0, count)
