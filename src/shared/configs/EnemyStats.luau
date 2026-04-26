export type EnemyData = {
	Name:   string,
	BaseHP: number,
	Speed:  number,
	Reward: number,
}

local EnemyStats: { [string]: EnemyData } = {
	["Bung Bung"] = {
		Name   = "Bung Bung",
		BaseHP = 80,
		Speed  = 12,
		Reward = 10,
	},
	["Jota Ele Dim Dim Dim"] = {
		Name   = "Jota Ele Dim Dim Dim",
		BaseHP = 60,
		Speed  = 22,
		Reward = 15,
	},
	["Bailarina Sapatina Boss"] = {
		Name   = "Bailarina Sapatina Boss",
		BaseHP = 800,
		Speed  = 7,
		Reward = 100,
	},
}

return EnemyStats
