local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EnemyStats = require(ReplicatedStorage.Shared.configs.EnemyStats)

local ENEMY_TAG          = "Enemy"
local BLOCK_DETECT_RANGE = 12  -- studs: cone de detecção de torres bloqueando
local ATTACK_RANGE       = 5   -- studs: distância para atacar a torre
local BLOCK_DOT          = 0.6 -- cos(~53°): cone frontal de detecção

local EnemyClass = {}
EnemyClass.__index = EnemyClass

export type StatsOverride = { hp: number?, speed: number? }?

-- Retorna o TowerClass mais próximo que está bloqueando o caminho ao próximo waypoint
local function findBlockingTower(myPos: Vector3, waypointPos: Vector3, activeTowers)
	local toWP     = waypointPos - myPos
	local horizFwd = Vector3.new(toWP.X, 0, toWP.Z)
	if horizFwd.Magnitude < 0.1 then return nil end
	horizFwd = horizFwd.Unit

	local closest, closestDist = nil, math.huge
	for _, towerObj in pairs(activeTowers) do
		if towerObj._dead then continue end
		local tp = towerObj.model and towerObj.model.PrimaryPart
		if not tp then continue end
		local toTower      = tp.Position - myPos
		local horizToTower = Vector3.new(toTower.X, 0, toTower.Z)
		local dist         = horizToTower.Magnitude
		if dist < 0.1 or dist > BLOCK_DETECT_RANGE then continue end
		local dot = horizToTower.Unit:Dot(horizFwd)
		if dot > BLOCK_DOT and dist < closestDist then
			closest     = towerObj
			closestDist = dist
		end
	end
	return closest
end

function EnemyClass.new(model: Model, enemyName: string, pivotAboveFloor: number, statsOverride: StatsOverride)
	local data = EnemyStats[enemyName]
	assert(data, ("[EnemyClass] '%s' não encontrado em EnemyStats"):format(enemyName))

	local hp    = (statsOverride and statsOverride.hp)    or data.BaseHP
	local speed = (statsOverride and statsOverride.speed) or data.Speed

	local self = setmetatable({
		model          = model,
		name           = enemyName,
		hp             = hp,
		maxHp          = hp,
		speed          = speed,
		reward         = data.Reward,
		damage         = data.Damage,
		attackCooldown = data.AttackCooldown,
		waypointIndex  = 1,
		_attackTimer   = 0,
		_dead          = false,
		_pivotAboveFloor = pivotAboveFloor,
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

local function moveToward(model: Model, primary: BasePart, targetPos: Vector3, speed: number, dt: number)
	local dir     = targetPos - primary.Position
	local step    = math.min(speed * dt, dir.Magnitude)
	local newPos  = primary.Position + dir.Unit * step
	local lookDir = Vector3.new(dir.X, 0, dir.Z)
	local newCF   = lookDir.Magnitude > 0.01
		and CFrame.new(newPos, newPos + lookDir)
		or  CFrame.new(newPos)
	model:PivotTo(newCF)
end

-- Returns true when base HP reaches 0 (game over)
local function attackBase(self, dt: number, baseRef: Instance): boolean
	local primary = self.model.PrimaryPart
	if not primary then return false end

	local basePart = (baseRef:IsA("BasePart") and baseRef)
		or (baseRef :: Model).PrimaryPart
		or baseRef:FindFirstChildWhichIsA("BasePart")
	local baseHP = baseRef:FindFirstChild("HP")
	if not (basePart and baseHP) then return true end

	local dist = (basePart.Position - primary.Position).Magnitude
	if dist > ATTACK_RANGE then
		moveToward(self.model, primary, basePart.Position, self.speed, dt)
		return false
	end

	if self._attackTimer <= 0 then
		self._attackTimer = self.attackCooldown;
		(baseHP :: IntValue).Value = math.max(0, (baseHP :: IntValue).Value - self.damage)
	end

	return (baseHP :: IntValue).Value <= 0
end

-- Returns true when base HP reaches 0 (triggers game over in EnemyService)
function EnemyClass:update(dt: number, waypoints: { BasePart }, activeTowers, baseRef: Instance?): boolean
	if self._dead or not self.model.Parent then return false end

	local primary = self.model.PrimaryPart
	if not primary then return false end

	if self._attackTimer > 0 then self._attackTimer -= dt end

	local wp = waypoints[self.waypointIndex]
	if not wp then
		-- Chegou ao fim do path: ataca a base até ela morrer
		if baseRef then
			return attackBase(self, dt, baseRef)
		end
		return true
	end

	-- Detecta torre bloqueando o caminho ao próximo waypoint
	if activeTowers then
		local blocker = findBlockingTower(primary.Position, wp.Position, activeTowers)
		if blocker then
			local tp = blocker.model and blocker.model.PrimaryPart
			if tp then
				local dist = (tp.Position - primary.Position).Magnitude
				if dist <= ATTACK_RANGE then
					-- Dentro do alcance: para e ataca
					if self._attackTimer <= 0 then
						self._attackTimer = self.attackCooldown
						blocker:takeDamage(self.damage)
					end
				else
					-- Fora do alcance: caminha até a torre
					moveToward(self.model, primary, tp.Position, self.speed, dt)
				end
			end
			return false
		end
	end

	-- Movimento normal em direção ao waypoint
	local target  = wp.Position + Vector3.new(0, self._pivotAboveFloor, 0)
	local current = primary.Position
	local dir     = target - current
	local dist2D  = Vector2.new(dir.X, dir.Z).Magnitude

	if dist2D < 2 then
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
