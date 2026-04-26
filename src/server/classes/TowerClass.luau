local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local TOWER_TAG  = "Tower"
local MELEE_RANGE = 5
local MELEE_DMG   = 10
local MELEE_TICK  = 1.0

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

	-- IntValues replicadas para o cliente (HP bars, nível)
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

	-- Aplica tint do nível se definido (snapshot restore com level > 1)
	if stats.Color then
		applyColor(model, stats.Color)
	end

	return self
end

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

function TowerClass:upgrade(): boolean
	local nextStats = self._towerData.Levels[self.level + 1]
	if not nextStats then return false end

	self.level  = self.level + 1
	self._stats = nextStats

	-- Atualiza IntValue de nível (replicado ao cliente)
	local lvlVal = self.model:FindFirstChild("Level")
	if lvlVal then (lvlVal :: IntValue).Value = self.level end

	-- Aplica tint visual se definido para este nível
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

	local target = findNearest(primary.Position, self._stats.Range, activeEnemies)
	if target then
		self._cooldownTimer = self._stats.Cooldown
		target:takeDamage(self._stats.Damage)
	end
end

return TowerClass
