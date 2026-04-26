local CollectionService = game:GetService("CollectionService")

local ENEMY_TAG = "Enemy"

local EnemyController = {}

-- ── Health bar ─────────────────────────────────────────────────────────────

local function getBarColor(pct)
	if pct > 0.6 then
		return Color3.fromRGB(0, 200, 60)
	elseif pct > 0.3 then
		return Color3.fromRGB(255, 165, 0)
	else
		return Color3.fromRGB(220, 40, 40)
	end
end

local function attachHealthBar(enemy)
	-- Aguarda PrimaryPart e IntValues estarem presentes
	local primary   = enemy.PrimaryPart
	local currentHP = enemy:WaitForChild("CurrentHP", 5)
	local maxHP     = enemy:WaitForChild("MaxHP",     5)

	if not (primary and currentHP and maxHP) then return end
	if maxHP.Value <= 0 then return end

	local billboard          = Instance.new("BillboardGui")
	billboard.Name           = "HealthBar"
	billboard.Size           = UDim2.new(0, 80, 0, 8)
	billboard.StudsOffset    = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop    = false
	billboard.MaxDistance    = 80
	billboard.ResetOnSpawn   = false
	billboard.Parent         = primary

	-- Fundo escuro
	local bg                 = Instance.new("Frame")
	bg.Size                  = UDim2.fromScale(1, 1)
	bg.BackgroundColor3      = Color3.fromRGB(25, 25, 25)
	bg.BorderSizePixel       = 0
	bg.Parent                = billboard

	-- Barra de HP
	local bar                = Instance.new("Frame")
	bar.Name                 = "Bar"
	bar.AnchorPoint          = Vector2.new(0, 0)
	bar.Size                 = UDim2.fromScale(1, 1)
	bar.BorderSizePixel      = 0
	bar.Parent               = bg

	local function update()
		local pct  = math.clamp(currentHP.Value / maxHP.Value, 0, 1)
		bar.Size                = UDim2.fromScale(pct, 1)
		bar.BackgroundColor3    = getBarColor(pct)
		billboard.Enabled       = pct < 1  -- esconde quando HP está cheio
	end

	currentHP:GetPropertyChangedSignal("Value"):Connect(update)
	update()
end

-- ── Init ───────────────────────────────────────────────────────────────────

function EnemyController:init()
	-- Inimigos já existentes (edge case em Studio Play Solo)
	for _, enemy in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		task.spawn(attachHealthBar, enemy)
	end

	-- Qualquer inimigo spawnado daqui pra frente
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(function(enemy)
		task.spawn(attachHealthBar, enemy)
	end)
end

return EnemyController
