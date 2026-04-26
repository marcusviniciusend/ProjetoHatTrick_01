export type TowerLevel = {
	Damage:      number,
	Range:       number,
	Cooldown:    number,
	UpgradeCost: number,
}

export type TowerData = {
	Name:      string,
	BasePrice: number,
	MaxHP:     number,
	Size:      Vector3,
	Color:     Color3,
	Levels:    { [number]: TowerLevel },
}

local TowerStats: { [string]: TowerData } = {
	["Toalete Basico"] = {
		Name      = "Toalete Basico",
		BasePrice = 100,
		MaxHP     = 150,
		Size      = Vector3.new(4, 4, 4),
		Color     = Color3.fromRGB(255, 255, 0),
		Levels    = {
			[1] = { Damage = 15, Range = 18, Cooldown = 1.0, UpgradeCost = 150 },
			[2] = { Damage = 25, Range = 20, Cooldown = 0.8, UpgradeCost = 300 },
		},
	},
	["Gerador de Brainrot"] = {
		Name      = "Gerador de Brainrot",
		BasePrice = 250,
		MaxHP     = 200,
		Size      = Vector3.new(4, 4, 4),
		Color     = Color3.fromRGB(0, 255, 0),
		Levels    = {
			[1] = { Damage = 35, Range = 24, Cooldown = 1.43, UpgradeCost = 400 },
			[2] = { Damage = 60, Range = 28, Cooldown = 1.0,  UpgradeCost = 700 },
		},
	},
	["Parede Neon"] = {
		Name      = "Parede Neon",
		BasePrice = 75,
		MaxHP     = 350,
		Size      = Vector3.new(8, 4, 2),
		Color     = Color3.fromRGB(255, 0, 255),
		Levels    = {
			[1] = { Damage = 0, Range = 0, Cooldown = 0, UpgradeCost = 0 },
		},
	},
}

return TowerStats
