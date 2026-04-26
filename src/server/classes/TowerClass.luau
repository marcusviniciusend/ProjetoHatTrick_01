local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local TOWER_TAG  = "Tower"
local MELEE_RANGE = 5    -- studs: inimigos dentro desse raio atacam a torre
local MELEE_DMG   = 10   -- dano por tick
local MELEE_TICK  = 1.0  -- segundos entre ticks de dano

local TowerClass = {}
TowerClass.__index = TowerClass

type ActiveEnemies = { [Model]: any }

local function findNearest(towerPos: Vector3, range: number, activeEnemies: ActiveEnemies)
	local nearest, nearestDist = nil, math.huge
	for _, enemyObj in pairs(activeEnemies) do
		if enemyObj._dead then continue end
		local primary = enemyObj.model and enemyObj.model.PrimaryPart
		if not primary then continue end
		local dist = (primary.Position - towerPos).Magnitude
		if dist <= range and dist < nearestDist then
			nearest     = enemyObj
			nearestDist = dist
		end
	end
	return nearest
end

function TowerClass.new(model: Model, towerName: string, level: number?)
	local towerData = TowerStats[towerName]
	assert(towerData, ("[TowerClass] '%s' não encontrado em TowerStats"):format(towerName))

	local lvl   = level or 1
	local stats = towerData.Levels[lvl]
	assert(stats, ("[TowerClass] Level %d não definido para '%s'"):format(lvl, towerName))

	local self = setmetatable({
		model          = model,
		name           = towerName,
		level          = lvl,
		basePrice      = towerData.BasePrice,
		hp             = towerData.MaxHP,
		maxHp          = towerData.MaxHP,
		_stats         = stats,
		_towerData     = towerData,
		_cooldownTimer = 0,
		_meleeCooldown = 0,
		_dead          = false,
	}, TowerClass)

	local curVal       = Instance.new("IntValue")
	curVal.Name        = "CurrentHP"
	curVal.Value       = towerData.MaxHP
	curVal.Parent      = model

	local maxVal       = Instance.new("IntValue")
	maxVal.Name        = "MaxHP"
	maxVal.Value       = towerData.MaxHP
	maxVal.Parent      = model

	CollectionService:AddTag(model, TOWER_TAG)

	return self
end

-- Returns true when the tower has just died
function TowerClass:takeDamage(amount: number): boolean
	if self._dead then return true end

	self.hp = math.max(0, self.hp - amount)

	local val = self.model:FindFirstChild("CurrentHP")
	if val then (val :: IntValue).Value = self.hp end

	if self.hp <= 0 then
		self._dead = true
	end

	return self._dead
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

	local target = findNearest(primary.Position, self._stats.Range, activeEnemies)
	if target then
		self._cooldownTimer = self._stats.Cooldown
		target:takeDamage(self._stats.Damage)
	end
end

function TowerClass:upgrade(): boolean
	local nextStats = self._towerData.Levels[self.level + 1]
	if not nextStats then return false end
	self.level  = self.level + 1
	self._stats = nextStats
	return true
end

function TowerClass:getUpgradeCost(): number?
	local cost = self._stats.UpgradeCost
	return cost > 0 and cost or nil
end

function TowerClass:getSellValue(): number
	return math.floor(self.basePrice * 0.5)
end

return TowerClass
