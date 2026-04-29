export type RarityInfo = {
	Weight:   number,
	MaxStock: number,
	Color:    Color3,
}

-- Para adicionar uma raridade: inserir aqui e referenciá-la em StoreItems.
local RarityData: { [string]: RarityInfo } = {
	Comum    = { Weight = 60, MaxStock = 5, Color = Color3.fromRGB(180, 180, 180) },
	Raro     = { Weight = 30, MaxStock = 3, Color = Color3.fromRGB(80, 120, 220)  },
	Lendario = { Weight = 10, MaxStock = 1, Color = Color3.fromRGB(255, 165, 0)   },
}

return RarityData
