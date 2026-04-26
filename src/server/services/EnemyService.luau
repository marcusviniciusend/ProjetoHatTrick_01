local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")

local EnemyService = {}

local activeEnemies = {}   -- { [model] = { hp, speed, waypointIndex } }
local waypoints     = {}   -- { Part } em ordem numérica
local onRemovedCb   = nil  -- chamado sempre que um inimigo morre ou chega na base

-- ── Setup ──────────────────────────────────────────────────────────────────

local function loadWaypoints()
	local map      = Workspace:FindFirstChild("Map")
	local wpFolder = map and map:FindFirstChild("Waypoints")
	if not wpFolder then
		warn("[EnemyService] Workspace.Map.Waypoints não encontrado — crie a pasta no Studio")
		return
	end
	waypoints = {}
	local i = 1
	while true do
		local wp = wpFolder:FindFirstChild(tostring(i))
		if not wp then break end
		table.insert(waypoints, wp)
		i += 1
	end
	print(("[EnemyService] %d waypoint(s) carregado(s)"):format(#waypoints))
end

function EnemyService:init(onRemovedCallback)
	onRemovedCb = onRemovedCallback
	loadWaypoints()

	-- Loop de movimento: roda em todo frame no servidor
	RunService.Heartbeat:Connect(function(dt)
		for enemy, data in pairs(activeEnemies) do
			if not enemy.Parent then
				activeEnemies[enemy] = nil
				continue
			end

			local primary = enemy.PrimaryPart
			if not primary then continue end

			local wp = waypoints[data.waypointIndex]
			if not wp then
				-- Inimigo chegou na base
				activeEnemies[enemy] = nil
				enemy:Destroy()
				EnemyService:_onReachedBase()
				continue
			end

			local target  = wp.Position + Vector3.new(0, primary.Size.Y / 2, 0)
			local current = primary.Position
			local dir     = target - current
			local dist    = dir.Magnitude

			if dist < 0.8 then
				data.waypointIndex += 1
			else
				local step    = math.min(data.speed * dt, dist)
				local newPos  = current + dir.Unit * step
				local lookDir = Vector3.new(dir.X, 0, dir.Z)

				local newCF = lookDir.Magnitude > 0.01
					and CFrame.new(newPos, newPos + lookDir)
					or  CFrame.new(newPos)

				enemy:SetPrimaryPartCFrame(newCF)
			end
		end
	end)
end

function EnemyService:_onReachedBase()
	local map  = Workspace:FindFirstChild("Map")
	local base = map and map:FindFirstChild("Base")
	if base and base:FindFirstChild("HP") then
		base.HP.Value = math.max(0, base.HP.Value - 1)
		print(("[EnemyService] Inimigo chegou na base! HP restante: %d"):format(base.HP.Value))
	else
		warn("[EnemyService] Workspace.Map.Base (com IntValue 'HP') não encontrado")
	end
	if onRemovedCb then onRemovedCb() end
end

-- ── API pública ────────────────────────────────────────────────────────────

function EnemyService:spawn(enemyName, statsOverride)
	if #waypoints == 0 then
		warn("[EnemyService] Sem waypoints — impossível spawnar")
		return nil
	end

	local folder   = ServerStorage:FindFirstChild("enemies")
	local template = folder and folder:FindFirstChild(enemyName)
	if not template then
		warn(("[EnemyService] '%s' não encontrado em ServerStorage.enemies"):format(enemyName))
		return nil
	end

	local clone = template:Clone()
	if not clone.PrimaryPart then
		warn(("[EnemyService] '%s' não tem PrimaryPart definido"):format(enemyName))
		clone:Destroy()
		return nil
	end

	local spawnPos = waypoints[1].Position + Vector3.new(0, clone.PrimaryPart.Size.Y / 2, 0)
	clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	clone.Parent = Workspace

	activeEnemies[clone] = {
		hp             = statsOverride and statsOverride.hp    or 100,
		speed          = statsOverride and statsOverride.speed or 14,
		waypointIndex  = 1,
	}

	return clone
end

function EnemyService:damage(enemy, amount)
	local data = activeEnemies[enemy]
	if not data then return end

	data.hp -= amount
	if data.hp <= 0 then
		activeEnemies[enemy] = nil
		enemy:Destroy()
		if onRemovedCb then onRemovedCb() end
	end
end

function EnemyService:getActive()
	return activeEnemies
end

function EnemyService:getActiveCount()
	local n = 0
	for _ in pairs(activeEnemies) do n += 1 end
	return n
end

return EnemyService
