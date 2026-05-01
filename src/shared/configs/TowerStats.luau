export type TowerLevel = {
	Damage:      number,
	Range:       number,
	Cooldown:    number,
	UpgradeCost: number,
	Color:       Color3?,   -- tint visual aplicado ao upgrade (nil = sem mudança)
}

export type TowerData = {
	Name:       string,
	BasePrice:  number,
	MaxHP:      number,
	Size:       Vector3,
	Color:      Color3,
	TargetMode: string?,    -- "First" | "Nearest"; nil defaults to "First"
	Levels:     { [number]: TowerLevel },
}

local TowerStats: { [string]: TowerData } = {
	["Toalete Basico"] = {
		Name       = "Toalete Basico",
		BasePrice  = 100,
		MaxHP      = 150,
		Size       = Vector3.new(4, 4, 4),
		Color      = Color3.fromRGB(255, 255, 0),
		TargetMode = "First",
		Levels     = {
			[1] = { Damage = 15, Range = 18, Cooldown = 1.0, UpgradeCost = 150 },
			[2] = { Damage = 25, Range = 20, Cooldown = 0.8, UpgradeCost = 300, Color = Color3.fromRGB(255, 200, 50) },
		},
	},
	["Gerador de Brainrot"] = {
		Name       = "Gerador de Brainrot",
		BasePrice  = 250,
		MaxHP      = 200,
		Size       = Vector3.new(4, 4, 4),
		Color      = Color3.fromRGB(0, 255, 0),
		TargetMode = "Nearest",
		Levels     = {
			[1] = { Damage = 35, Range = 24, Cooldown = 1.43, UpgradeCost = 400 },
			[2] = { Damage = 60, Range = 28, Cooldown = 1.0,  UpgradeCost = 700, Color = Color3.fromRGB(0, 255, 120) },
		},
	},
	["Mortair"] = {
		Name       = "Mortair",
		BasePrice  = 100,
		MaxHP      = 150,
		Size       = Vector3.new(4, 4, 4),
		Color      = Color3.fromRGB(255, 255, 0),
		TargetMode = "First",
		Levels     = {
			[1] = { Damage = 15, Range = 18, Cooldown = 1.0, UpgradeCost = 150 },
			[2] = { Damage = 25, Range = 20, Cooldown = 0.8, UpgradeCost = 300, Color = Color3.fromRGB(255, 200, 50) },
		},
	},
}

return TowerStats
