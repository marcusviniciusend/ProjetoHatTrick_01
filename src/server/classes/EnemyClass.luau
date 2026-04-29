local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EnemyStats = require(ReplicatedStorage.Shared.configs.EnemyStats)

local ENEMY_TAG          = "Enemy"
local BLOCK_DETECT_RANGE = 12
local ATTACK_RANGE       = 5
local BLOCK_DOT          = 0.6

local EnemyClass = {}
EnemyClass.__index = EnemyClass

export type StatsOverride = { hp: number?, speed: number? }?

local function findBlockingTower(myPos: Vector3, waypointPos: Vector3, activeTowers)
	local toWP     = waypointPos - myPos
	local horizFwd = Vector3.new(toWP.X, 0, toWP.Z)
	if horizFwd.Magnitude < 0.1 then return nil end
	horizFwd = horizFwd.Unit

	local closest, closestDist = nil, math.huge
	for _, tower in pairs(activeTowers) do
		if tower._dead then continue end
		local pp = tower.model and tower.model.PrimaryPart
		if not pp then continue end

		local delta = Vector3.new(pp.Position.X - myPos.X, 0, pp.Position.Z - myPos.Z)
		local dist  = delta.Magnitude
		if dist < 0.1 or dist > BLOCK_DETECT_RANGE then continue end
		if delta.Unit:Dot(horizFwd) > BLOCK_DOT and dist < closestDist then
			closest, closestDist = tower, dist
		end
	end
	return closest
end

local function moveToward(model: Model, primary: BasePart, targetPos: Vector3, speed: number, dt: number)
	local dir    = targetPos - primary.Position
	local newPos = primary.Position + dir.Unit * math.min(speed * dt, dir.Magnitude)
	local flat   = Vector3.new(dir.X, 0, dir.Z)
	model:PivotTo(
		flat.Magnitude > 0.01
			and CFrame.new(newPos, newPos + flat)
			or  CFrame.new(newPos)
	)
end

local function resolveBasePart(baseRef: Instance): BasePart?
	if baseRef:IsA("BasePart") then return baseRef :: BasePart end
	local m = baseRef :: Model
	return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end

function EnemyClass.new(model: Model, enemyName: string, pivotAboveFloor: number, targetPlot: Model, statsOverride: StatsOverride)
	local data = EnemyStats[enemyName]
	assert(data, ("[EnemyClass] '%s' não encontrado em EnemyStats"):format(enemyName))

	local hp    = (statsOverride and statsOverride.hp)    or data.BaseHP
	local speed = (statsOverride and statsOverride.speed) or data.Speed

	local curVal  = Instance.new("IntValue")
	curVal.Name   = "CurrentHP"
	curVal.Value  = hp
	curVal.Parent = model

	local maxVal  = Instance.new("IntValue")
	maxVal.Name   = "MaxHP"
	maxVal.Value  = hp
	maxVal.Parent = model

	CollectionService:AddTag(model, ENEMY_TAG)

	return setmetatable({
		model            = model,
		name             = enemyName,
		hp               = hp,
		maxHp            = hp,
		speed            = speed,
		reward           = data.Reward,
		damage           = data.Damage,
		attackCooldown   = data.AttackCooldown,
		waypointIndex    = 1,
		_attackTimer     = 0,
		_dead            = false,
		_pivotAboveFloor = pivotAboveFloor,
		_hpValue         = curVal,   -- cached: evita FindFirstChild a cada takeDamage
		targetPlot       = targetPlot,
		onDied           = nil,      -- (reward, targetPlot) → void; setado pelo EnemyService
	}, EnemyClass)
end

-- Retorna true quando HP chega a 0; recompensa sempre vai para o dono do plot.
function EnemyClass:takeDamage(amount: number): boolean
	if self._dead then return true end

	self.hp               = math.max(0, self.hp - amount)
	self._hpValue.Value   = self.hp

	if self.hp <= 0 then
		self._dead = true
		if self.onDied then
			self.onDied(self.reward, self.targetPlot)
		end
	end

	return self._dead
end

function EnemyClass:_attackBase(dt: number, baseRef: Instance): boolean
	local primary = self.model.PrimaryPart
	if not primary then return false end

	local basePart = resolveBasePart(baseRef)
	local baseHP   = baseRef:FindFirstChild("HP") :: IntValue?
	if not (basePart and baseHP) then return true end

	if (basePart.Position - primary.Position).Magnitude > ATTACK_RANGE then
		moveToward(self.model, primary, basePart.Position, self.speed, dt)
		return false
	end

	if self._attackTimer <= 0 then
		self._attackTimer = self.attackCooldown
		baseHP.Value      = math.max(0, baseHP.Value - self.damage)
	end

	return baseHP.Value <= 0
end

-- Retorna true quando HP da base chega a 0 (game over).
function EnemyClass:update(dt: number, waypoints: { BasePart }, activeTowers, baseRef: Instance?): boolean
	if self._dead or not self.model.Parent then return false end

	local primary = self.model.PrimaryPart
	if not primary then return false end

	if self._attackTimer > 0 then self._attackTimer -= dt end

	local wp = waypoints[self.waypointIndex]
	if not wp then
		return baseRef and self:_attackBase(dt, baseRef) or true
	end

	local blocker = activeTowers and findBlockingTower(primary.Position, wp.Position, activeTowers)
	if blocker then
		local pp = blocker.model and blocker.model.PrimaryPart
		if pp then
			if (pp.Position - primary.Position).Magnitude <= ATTACK_RANGE then
				if self._attackTimer <= 0 then
					self._attackTimer = self.attackCooldown
					blocker:takeDamage(self.damage)
				end
			else
				moveToward(self.model, primary, pp.Position, self.speed, dt)
			end
		end
		return false
	end

	local target = wp.Position + Vector3.new(0, self._pivotAboveFloor, 0)
	local dir    = target - primary.Position
	if Vector2.new(dir.X, dir.Z).Magnitude < 2 then
		self.waypointIndex += 1
	else
		moveToward(self.model, primary, target, self.speed, dt)
	end

	return false
end

function EnemyClass:destroy()
	if self.model and self.model.Parent then
		self.model:Destroy()
	end
end

return EnemyClass
