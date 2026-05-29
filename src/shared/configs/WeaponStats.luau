export type WeaponData = {
	-- Identidade
	DisplayName     : string,
	Type            : "Melee" | "Ranged",
	BasePrice       : number,
	IsSpecial       : boolean,

	-- Combate
	Damage          : number,
	Cooldown        : number,

	-- Melee
	FrontRange      : number?,
	CleaveAngle     : number?,
	CleaveRange     : number?,

	-- Ranged
	Range           : number?,
	ProjectileSpeed : number?,
	SplashRadius    : number?,

	-- Efeitos
	Passive         : string?,
}

local WeaponStats: { [string]: WeaponData } = {

	["Espada dos Bárbaros"] = {
		DisplayName = "Espada dos Bárbaros",
		Type        = "Melee",
		BasePrice   = 150,
		IsSpecial   = false,
		Damage      = 40,
		Cooldown    = 0.8,
		FrontRange  = 8,
	},

	["Arco e Flecha"] = {
		DisplayName     = "Arco e Flecha",
		Type            = "Ranged",
		BasePrice       = 180,
		IsSpecial       = false,
		Damage          = 30,
		Cooldown        = 0.6,
		Range           = math.huge,
		ProjectileSpeed = 80,
	},

	["Adagas dos Goblins"] = {
		DisplayName = "Adagas dos Goblins",
		Type        = "Melee",
		BasePrice   = 120,
		IsSpecial   = false,
		Damage      = 15,
		Cooldown    = 0.25,
		FrontRange  = 5,
		Passive     = "CoinOnHit",
	},

	["Espada do Rei Bárbaro"] = {
		DisplayName  = "Espada do Rei Bárbaro",
		Type         = "Melee",
		BasePrice    = 500,
		IsSpecial    = true,
		Damage       = 120,
		Cooldown     = 1.0,
		CleaveAngle  = 120,
		CleaveRange  = 12,
	},

	["Besta da Rainha"] = {
		DisplayName     = "Besta da Rainha",
		Type            = "Ranged",
		BasePrice       = 600,
		IsSpecial       = true,
		Damage          = 200,
		Cooldown        = 0.3,
		Range           = math.huge,
		ProjectileSpeed = 300,
	},

	["Cajado da Bruxa"] = {
		DisplayName     = "Cajado da Bruxa",
		Type            = "Ranged",
		BasePrice       = 550,
		IsSpecial       = true,
		Damage          = 80,
		Cooldown        = 1.2,
		Range           = math.huge,
		ProjectileSpeed = 60,
		SplashRadius    = 12,
	},

	["Cajado Bruxa Sombria"] = {
		DisplayName = "Cajado Bruxa Sombria",
		Type        = "Melee",
		BasePrice   = 650,
		IsSpecial   = true,
		Damage      = 180,
		Cooldown    = 1.5,
		FrontRange  = 7,
	},
}

return WeaponStats
