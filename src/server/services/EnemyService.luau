local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")

local EnemyClass = require(script.Parent.Parent.classes.EnemyClass)

local EnemyService = {}

local activeEnemies  = {}   -- { [Model]: EnemyClass }
local waypoints      = {}
local baseRef        = nil
local onRemovedCb    = nil
local onGameOverCb   = nil
local gameStopped    = false
local _towerProvider = nil  -- injetado por TowerService para evitar require circular

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

			local activeTowers = _towerProvider and _towerProvider() or nil
			local gameOver     = enemyObj:update(dt, waypoints, activeTowers, baseRef)
			if gameOver then
				activeEnemies[model] = nil
				enemyObj:destroy()
				EnemyService:_onGameOver()
				break
			end
		end
	end)
end

function EnemyService:clearAllEnemies()
	for _, enemyObj in pairs(activeEnemies) do
		enemyObj:destroy()
	end
	activeEnemies = {}
end

function EnemyService:_onGameOver()
	gameStopped = true
	self:clearAllEnemies()
	if onGameOverCb then onGameOverCb() end
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

	-- Movimento é feito via PivotTo; física simulada causaria arremesso ao spawnar
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
		end
	end

	-- Parear ANTES de GetBoundingBox: em modelos não-pareados o método pode
	-- retornar espaço de objeto em vez de espaço de mundo.
	-- Tudo já está ancorado + CanCollide=false, então a física não age.
	clone.Parent = Workspace

	-- Distância do pivot até a borda inferior real do modelo no mundo.
	local boundCF, boundSize = clone:GetBoundingBox()
	local pivotY          = clone:GetPivot().Position.Y
	local bottomY         = boundCF.Position.Y - boundSize.Y / 2
	local pivotAboveFloor = pivotY - bottomY  -- offset relativo, invariante após PivotTo

	local wp1      = waypoints[1].Position
	clone:PivotTo(CFrame.new(wp1.X, wp1.Y + pivotAboveFloor, wp1.Z))

	local enemyObj = EnemyClass.new(clone, enemyName, pivotAboveFloor, statsOverride)
	activeEnemies[clone] = enemyObj

	return clone
end

function EnemyService:setTowerProvider(fn)
	_towerProvider = fn
end

function EnemyService:reset()
	gameStopped = false
	self:clearAllEnemies()
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
