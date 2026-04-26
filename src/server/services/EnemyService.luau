local RunService       = game:GetService("RunService")
local ServerStorage    = game:GetService("ServerStorage")
local Workspace        = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ENEMY_TAG = "Enemy"

local EnemyService = {}

local activeEnemies = {}
local waypoints     = {}
local baseRef       = nil  -- usado só para HP, não para movimento
local onRemovedCb   = nil
local onGameOverCb  = nil
local gameStopped   = false

-- ── Setup ──────────────────────────────────────────────────────────────────

local function loadMap()
	local map      = Workspace:FindFirstChild("Map")
	local wpFolder = map and map:FindFirstChild("Waypoints")

	if wpFolder then
		waypoints = {}
		local i = 1
		while true do
			local wp = wpFolder:FindFirstChild(tostring(i))
			if not wp then break end

			-- Garante que waypoints não caiam nem bloqueiem inimigos
			if wp:IsA("BasePart") then
				wp.Anchored     = true
				wp.CanCollide   = false
				wp.CanQuery     = false
				wp.CanTouch     = false
				wp.Transparency = 1
				wp.CastShadow   = false
			end

			table.insert(waypoints, wp)
			i += 1
		end
		print(("[EnemyService] %d waypoint(s) carregado(s)"):format(#waypoints))
	else
		warn("[EnemyService] Workspace.Map.Waypoints não encontrado")
	end

	-- Base: só para HP — posicione o ÚLTIMO waypoint em cima da Base no Studio
	baseRef = map and map:FindFirstChild("Base")
	if baseRef then
		print("[EnemyService] Base.HP encontrado")
	else
		warn("[EnemyService] Workspace.Map.Base não encontrado — HP não será decrementado")
	end
end

function EnemyService:init(onRemovedCallback, onGameOverCallback)
	onRemovedCb  = onRemovedCallback
	onGameOverCb = onGameOverCallback
	gameStopped  = false
	loadMap()

	RunService.Heartbeat:Connect(function(dt)
		if gameStopped then return end

		for enemy, data in pairs(activeEnemies) do
			if not enemy.Parent then
				activeEnemies[enemy] = nil
				continue
			end

			local primary = enemy.PrimaryPart
			if not primary then continue end

			local wp = waypoints[data.waypointIndex]

			if not wp then
				-- Passou pelo último waypoint → chegou na base
				activeEnemies[enemy] = nil
				enemy:Destroy()
				EnemyService:_onReachedBase()
				continue
			end

			local target  = wp.Position + Vector3.new(0, primary.Size.Y / 2, 0)
			local current = primary.Position
			local dir     = target - current

			-- Usa distância XZ (ignora Y) para não travar por diferença de altura
			local dist2D = Vector2.new(dir.X, dir.Z).Magnitude

			if dist2D < 2 then
				data.waypointIndex += 1
			else
				local step    = math.min(data.speed * dt, dir.Magnitude)
				local newPos  = current + dir.Unit * step
				local lookDir = Vector3.new(dir.X, 0, dir.Z)
				local newCF   = lookDir.Magnitude > 0.01
					and CFrame.new(newPos, newPos + lookDir)
					or  CFrame.new(newPos)
				enemy:SetPrimaryPartCFrame(newCF)
			end
		end
	end)
end

function EnemyService:_onReachedBase()
	local hp = baseRef and baseRef:FindFirstChild("HP")

	if hp then
		hp.Value = math.max(0, hp.Value - 1)
		print(("[EnemyService] Inimigo chegou na base! HP: %d"):format(hp.Value))

		if hp.Value <= 0 then
			gameStopped = true
			for enemy in pairs(activeEnemies) do
				if enemy.Parent then enemy:Destroy() end
			end
			activeEnemies = {}
			if onGameOverCb then onGameOverCb() end
			return
		end
	else
		warn("[EnemyService] Base.HP não encontrado")
	end

	if onRemovedCb then onRemovedCb() end
end

-- ── API pública ────────────────────────────────────────────────────────────

function EnemyService:spawn(enemyName, statsOverride)
	if gameStopped or #waypoints == 0 then return nil end

	local folder   = ServerStorage:FindFirstChild("enemies")
	local template = folder and folder:FindFirstChild(enemyName)
	if not template then
		warn(("[EnemyService] '%s' não encontrado em ServerStorage.enemies"):format(enemyName))
		return nil
	end

	local clone = template:Clone()
	if not clone.PrimaryPart then
		warn(("[EnemyService] '%s' sem PrimaryPart definido"):format(enemyName))
		clone:Destroy()
		return nil
	end

	local spawnPos = waypoints[1].Position + Vector3.new(0, clone.PrimaryPart.Size.Y / 2, 0)
	local hp = statsOverride and statsOverride.hp or 100

	clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	clone.Parent = Workspace

	-- IntValues replicados → cliente usa para health bar sem RemoteEvent
	local currentHPVal       = Instance.new("IntValue")
	currentHPVal.Name        = "CurrentHP"
	currentHPVal.Value       = hp
	currentHPVal.Parent      = clone

	local maxHPVal           = Instance.new("IntValue")
	maxHPVal.Name            = "MaxHP"
	maxHPVal.Value           = hp
	maxHPVal.Parent          = clone

	CollectionService:AddTag(clone, ENEMY_TAG)

	activeEnemies[clone] = {
		hp            = hp,
		speed         = statsOverride and statsOverride.speed or 14,
		waypointIndex = 1,
	}

	return clone
end

function EnemyService:damage(enemy, amount)
	if gameStopped then return end
	local data = activeEnemies[enemy]
	if not data then return end

	data.hp -= amount

	-- Atualiza IntValue replicada (cliente sincroniza a health bar automaticamente)
	local currentHPVal = enemy:FindFirstChild("CurrentHP")
	if currentHPVal then
		currentHPVal.Value = math.max(0, data.hp)
	end

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
