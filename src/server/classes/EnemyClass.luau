local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EnemyStats = require(ReplicatedStorage.Shared.configs.EnemyStats)

local ENEMY_TAG = "Enemy"

local EnemyClass = {}
EnemyClass.__index = EnemyClass

export type StatsOverride = { hp: number?, speed: number? }?

function EnemyClass.new(model: Model, enemyName: string, statsOverride: StatsOverride)
	local data = EnemyStats[enemyName]
	assert(data, ("[EnemyClass] '%s' não encontrado em EnemyStats"):format(enemyName))

	local hp    = (statsOverride and statsOverride.hp)    or data.BaseHP
	local speed = (statsOverride and statsOverride.speed) or data.Speed

	local self = setmetatable({
		model         = model,
		name          = enemyName,
		hp            = hp,
		maxHp         = hp,
		speed         = speed,
		reward        = data.Reward,
		waypointIndex = 1,
		_dead         = false,
	}, EnemyClass)

	local curVal       = Instance.new("IntValue")
	curVal.Name        = "CurrentHP"
	curVal.Value       = hp
	curVal.Parent      = model

	local maxVal       = Instance.new("IntValue")
	maxVal.Name        = "MaxHP"
	maxVal.Value       = hp
	maxVal.Parent      = model

	CollectionService:AddTag(model, ENEMY_TAG)

	return self
end

-- Returns true when the enemy has just died
function EnemyClass:takeDamage(amount: number): boolean
	if self._dead then return true end

	self.hp = math.max(0, self.hp - amount)

	local val = self.model:FindFirstChild("CurrentHP")
	if val then (val :: IntValue).Value = self.hp end

	if self.hp <= 0 then
		self._dead = true
	end

	return self._dead
end

-- Returns true when the enemy has walked past the last waypoint (reached base)
function EnemyClass:update(dt: number, waypoints: { BasePart }): boolean
	if self._dead or not self.model.Parent then return false end

	local primary = self.model.PrimaryPart
	if not primary then return false end

	local wp = waypoints[self.waypointIndex]
	if not wp then return true end

	local target  = wp.Position + Vector3.new(0, primary.Size.Y / 2, 0)
	local current = primary.Position
	local dir     = target - current
	local dist2D  = Vector2.new(dir.X, dir.Z).Magnitude

	if dist2D < 2 then
		self.waypointIndex += 1
	else
		local step    = math.min(self.speed * dt, dir.Magnitude)
		local newPos  = current + dir.Unit * step
		local lookDir = Vector3.new(dir.X, 0, dir.Z)
		local newCF   = lookDir.Magnitude > 0.01
			and CFrame.new(newPos, newPos + lookDir)
			or  CFrame.new(newPos)
		self.model:PivotTo(newCF)
	end

	return false
end

function EnemyClass:destroy()
	if self.model and self.model.Parent then
		self.model:Destroy()
	end
end

return EnemyClass
