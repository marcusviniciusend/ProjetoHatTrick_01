local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local TowerClass = {}
TowerClass.__index = TowerClass

-- ActiveEnemies is { [Model]: EnemyClass } — typed loosely to avoid circular import
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

	return setmetatable({
		model          = model,
		name           = towerName,
		level          = lvl,
		basePrice      = towerData.BasePrice,
		_stats         = stats,
		_towerData     = towerData,
		_cooldownTimer = 0,
	}, TowerClass)
end

function TowerClass:update(dt: number, activeEnemies: ActiveEnemies)
	if not self.model.Parent then return end
	if self._stats.Damage <= 0 then return end

	self._cooldownTimer -= dt
	if self._cooldownTimer > 0 then return end

	local primary = self.model.PrimaryPart
	if not primary then return end

	local target = findNearest(primary.Position, self._stats.Range, activeEnemies)
	if target then
		self._cooldownTimer = self._stats.Cooldown
		target:takeDamage(self._stats.Damage)
	end
end

-- Returns true if upgraded successfully
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
