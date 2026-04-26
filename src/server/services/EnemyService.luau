local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")

local EnemyClass = require(script.Parent.Parent.classes.EnemyClass)

local EnemyService = {}

local activeEnemies = {}  -- { [Model]: EnemyClass }
local waypoints     = {}
local baseRef       = nil
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

			if wp:IsA("BasePart") or wp:IsA("MeshPart") then
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

	baseRef = map and map:FindFirstChild("Base")
	if baseRef then
		print("[EnemyService] Base encontrada")
	else
		warn("[EnemyService] Workspace.Map.Base não encontrado")
	end
end

function EnemyService:init(onRemovedCallback, onGameOverCallback)
	onRemovedCb  = onRemovedCallback
	onGameOverCb = onGameOverCallback
	gameStopped  = false
	loadMap()

	RunService.Heartbeat:Connect(function(dt)
		if gameStopped then return end

		for model, enemyObj in pairs(activeEnemies) do
			if not model.Parent then
				activeEnemies[model] = nil
				continue
			end

			if enemyObj._dead then
				activeEnemies[model] = nil
				enemyObj:destroy()
				if onRemovedCb then onRemovedCb() end
				continue
			end

			local reachedBase = enemyObj:update(dt, waypoints)
			if reachedBase then
				activeEnemies[model] = nil
				enemyObj:destroy()
				EnemyService:_onReachedBase()
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
			for _, enemyObj in pairs(activeEnemies) do
				enemyObj:destroy()
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

function EnemyService:spawn(enemyName: string, statsOverride)
	if gameStopped or #waypoints == 0 then return nil end

	local folder   = ServerStorage:FindFirstChild("enemies")
	local template = folder and folder:FindFirstChild(enemyName)
	if not template then
		warn(("[EnemyService] '%s' não encontrado em ServerStorage.enemies"):format(enemyName))
		return nil
	end

	local clone = template:Clone()
	if not clone.PrimaryPart then
		warn(("[EnemyService] '%s' sem PrimaryPart"):format(enemyName))
		clone:Destroy()
		return nil
	end

	local spawnPos = waypoints[1].Position + Vector3.new(0, clone.PrimaryPart.Size.Y / 2, 0)
	clone:PivotTo(CFrame.new(spawnPos))
	clone.Parent = Workspace

	local enemyObj = EnemyClass.new(clone, enemyName, statsOverride)
	activeEnemies[clone] = enemyObj

	return clone
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
