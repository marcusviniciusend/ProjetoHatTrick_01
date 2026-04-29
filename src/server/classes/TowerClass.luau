local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local TOWER_TAG    = "Tower"
local MELEE_RANGE  = 5
local MELEE_DMG    = 10
local MELEE_TICK   = 1.0

local TowerClass = {}
TowerClass.__index = TowerClass

type ActiveEnemies = { [Model]: any }

-- "First"   → inimigo mais avançado no percurso (maior waypointIndex, desempate por distância)
-- "Nearest" → inimigo mais próximo da torre
local function findTarget(towerPos: Vector3, range: number, activeEnemies: ActiveEnemies, mode: string)
	local best, bestScore = nil, nil

	for _, enemyObj in pairs(activeEnemies) do
		if enemyObj._dead then continue end
		local primary = enemyObj.model and enemyObj.model.PrimaryPart
		if not primary then continue end

		local dist = (primary.Position - towerPos).Magnitude
		if dist > range then continue end

		-- score maior = prioridade maior
		local score: number
		if mode == "Nearest" then
			score = -dist
		else  -- "First"
			-- waypointIndex * 10000 garante que qualquer índice maior sempre vence,
			-- com distância como desempate (mais próximo ganha entre mesmos índices)
			score = enemyObj.waypointIndex * 10000 - dist
		end

		if bestScore == nil or score > bestScore then
			best      = enemyObj
			bestScore = score
		end
	end

	return best
end

local function applyColor(model: Model, color: Color3)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = color
		end
	end
	if model.PrimaryPart then
		model.PrimaryPart.Color = color
	end
end

function TowerClass.new(model: Model, towerName: string, level: number?)
	local towerData = TowerStats[towerName]
	assert(towerData, ("[TowerClass] '%s' não encontrado em TowerStats"):format(towerName))

	local lvl   = level or 1
	local stats = towerData.Levels[lvl]
	assert(stats, ("[TowerClass] Level %d não definido para '%s'"):format(lvl, towerName))

	-- Cria IntValues antes do setmetatable para poder cachear as referências
	local curVal   = Instance.new("IntValue")
	curVal.Name    = "CurrentHP"
	curVal.Value   = towerData.MaxHP
	curVal.Parent  = model

	local maxVal   = Instance.new("IntValue")
	maxVal.Name    = "MaxHP"
	maxVal.Value   = towerData.MaxHP
	maxVal.Parent  = model

	local lvlVal   = Instance.new("IntValue")
	lvlVal.Name    = "Level"
	lvlVal.Value   = lvl
	lvlVal.Parent  = model

	local nameVal  = Instance.new("StringValue")
	nameVal.Name   = "TowerName"
	nameVal.Value  = towerName
	nameVal.Parent = model

	CollectionService:AddTag(model, TOWER_TAG)

	if stats.Color then
		applyColor(model, stats.Color)
	end

	return setmetatable({
		model          = model,
		name           = towerName,
		level          = lvl,
		basePrice      = towerData.BasePrice,
		hp             = towerData.MaxHP,
		maxHp          = towerData.MaxHP,
		_stats         = stats,
		_towerData     = towerData,
		_targetMode    = towerData.TargetMode or "First",
		_cooldownTimer = 0,
		_meleeCooldown = 0,
		_dead          = false,
		_hpValue       = curVal,   -- cached: evita FindFirstChild a cada takeDamage
	}, TowerClass)
end

function TowerClass:takeDamage(amount: number): boolean
	if self._dead then return true end

	self.hp             = math.max(0, self.hp - amount)
	self._hpValue.Value = self.hp

	if self.hp <= 0 then
		self._dead = true
	end

	return self._dead
end

function TowerClass:upgrade(): boolean
	local nextStats = self._towerData.Levels[self.level + 1]
	if not nextStats then return false end

	self.level  = self.level + 1
	self._stats = nextStats

	local lvlVal = self.model:FindFirstChild("Level")
	if lvlVal then (lvlVal :: IntValue).Value = self.level end

	if nextStats.Color then
		applyColor(self.model, nextStats.Color)
	end

	return true
end

function TowerClass:destroy()
	self._dead = true
	if self.model and self.model.Parent then
		self.model:Destroy()
	end
end

function TowerClass:getUpgradeCost(): number?
	local nextStats = self._towerData.Levels[self.level + 1]
	if not nextStats then return nil end
	return nextStats.UpgradeCost > 0 and nextStats.UpgradeCost or nil
end

function TowerClass:getSellValue(): number
	return math.floor(self.basePrice * 0.5)
end

function TowerClass:update(dt: number, activeEnemies: ActiveEnemies)
	if not self.model.Parent or self._dead then return end

	local primary = self.model.PrimaryPart
	if not primary then return end

	-- Inimigos próximos causam dano melee na torre
	self._meleeCooldown -= dt
	if self._meleeCooldown <= 0 then
		self._meleeCooldown = MELEE_TICK
		for _, enemyObj in pairs(activeEnemies) do
			if enemyObj._dead then continue end
			local ePrimary = enemyObj.model and enemyObj.model.PrimaryPart
			if not ePrimary then continue end
			if (ePrimary.Position - primary.Position).Magnitude <= MELEE_RANGE then
				self:takeDamage(MELEE_DMG)
				break
			end
		end
	end

	if self._dead or self._stats.Damage <= 0 then return end

	self._cooldownTimer -= dt
	if self._cooldownTimer > 0 then return end

	local target = findTarget(primary.Position, self._stats.Range, activeEnemies, self._targetMode)
	if target then
		self._cooldownTimer = self._stats.Cooldown
		target:takeDamage(self._stats.Damage)
	end
end

return TowerClass
