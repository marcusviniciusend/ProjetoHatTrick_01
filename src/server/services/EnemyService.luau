local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")

local EnemyClass = require(script.Parent.Parent.classes.EnemyClass)

local EnemyService = {}

-- { [model: Model]: { obj: EnemyClass, plot: Model } }
local activeEnemies  = {}

-- { [plot: Model]: { waypoints: {BasePart}, base: Instance?, initialBaseHP: number } }
local plotData       = {}

local onRemovedCb    = nil
local onGameOverCb   = nil
local gameStopped    = false
local _towerProvider = nil

-- ── Setup ──────────────────────────────────────────────────────────────────

local function configureWaypoint(wp: BasePart)
	wp.Anchored     = true
	wp.CanCollide   = false
	wp.CanQuery     = false
	wp.CanTouch     = false
	wp.Transparency = 1
	wp.CastShadow   = false
end

-- Carrega waypoints e base de cada Plot dentro de Map.Plots.
-- Estrutura esperada: Map > Plots > PlotN > Waypoints > 1, 2, 3…
--                                         > Base
local function loadPlots()
	local map = Workspace:FindFirstChild("Map")
	local plotsFolder = map and map:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[EnemyService] Workspace.Map.Plots não encontrado")
		return
	end

	plotData = {}
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end

		local wpFolder = plot:FindFirstChild("Waypoints")
		local base     = plot:FindFirstChild("Base")

		local wps = {}
		if wpFolder then
			local i = 1
			while true do
				local wp = wpFolder:FindFirstChild(tostring(i))
				if not wp then break end
				if wp:IsA("BasePart") then configureWaypoint(wp) end
				table.insert(wps, wp)
				i += 1
			end
		end

		local baseHP         = base and base:FindFirstChild("HP")
		local initialBaseHP  = baseHP and (baseHP :: IntValue).Value or 100

		plotData[plot] = { waypoints = wps, base = base, initialBaseHP = initialBaseHP }
		print(("[EnemyService] '%s': %d waypoint(s), base=%s"):format(
			plot.Name, #wps, tostring(base ~= nil)))
	end
end

function EnemyService:init(onRemovedCallback, onGameOverCallback)
	onRemovedCb  = onRemovedCallback
	onGameOverCb = onGameOverCallback
	gameStopped  = false
	loadPlots()

	RunService.Heartbeat:Connect(function(dt)
		if gameStopped then return end

		for model, info in pairs(activeEnemies) do
			if not model.Parent then
				activeEnemies[model] = nil
				continue
			end

			if info.obj._dead then
				activeEnemies[model] = nil
				info.obj:destroy()
				if onRemovedCb then onRemovedCb() end
				continue
			end

			local pData        = plotData[info.plot]
			local activeTowers = _towerProvider and _towerProvider() or nil
			local gameOver     = info.obj:update(
				dt,
				pData and pData.waypoints or {},
				activeTowers,
				pData and pData.base or nil
			)

			if gameOver then
				activeEnemies[model] = nil
				info.obj:destroy()
				EnemyService:_onGameOver()
				break
			end
		end
	end)
end

function EnemyService:clearAllEnemies()
	for _, info in pairs(activeEnemies) do
		info.obj:destroy()
	end
	activeEnemies = {}
end

-- Restaura o HP da base de todos os plots para o valor inicial.
function EnemyService:resetBases()
	for _, pData in pairs(plotData) do
		local base = pData.base
		if not base then continue end
		local hp = base:FindFirstChild("HP")
		if hp then (hp :: IntValue).Value = pData.initialBaseHP end
	end
end

function EnemyService:_onGameOver()
	gameStopped = true
	self:clearAllEnemies()
	if onGameOverCb then onGameOverCb() end
end

-- ── API pública ────────────────────────────────────────────────────────────

-- Spawna um inimigo no caminho do plot indicado.
function EnemyService:spawn(enemyName: string, plot: Model, statsOverride)
	if gameStopped then return nil end

	local pData = plotData[plot]
	if not pData or #pData.waypoints == 0 then
		warn(("[EnemyService] Plot '%s' sem waypoints — inimigo não spawnado"):format(
			plot and plot.Name or "?"))
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
		warn(("[EnemyService] '%s' sem PrimaryPart"):format(enemyName))
		clone:Destroy()
		return nil
	end

	-- Movimento via PivotTo — física não deve simular
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
		end
	end

	-- Parear antes de GetBoundingBox para garantir coordenadas de mundo corretas
	clone.Parent = Workspace

	local boundCF, boundSize = clone:GetBoundingBox()
	local pivotY          = clone:GetPivot().Position.Y
	local pivotAboveFloor = pivotY - (boundCF.Position.Y - boundSize.Y / 2)

	local wp1 = pData.waypoints[1].Position
	clone:PivotTo(CFrame.new(wp1.X, wp1.Y + pivotAboveFloor, wp1.Z))

	local enemyObj = EnemyClass.new(clone, enemyName, pivotAboveFloor, statsOverride)
	activeEnemies[clone] = { obj = enemyObj, plot = plot }

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
	-- Retorna { [Model]: EnemyClass } para compatibilidade com TowerService
	local out = {}
	for model, info in pairs(activeEnemies) do
		out[model] = info.obj
	end
	return out
end

function EnemyService:getActiveCount()
	local n = 0
	for _ in pairs(activeEnemies) do n += 1 end
	return n
end

return EnemyService
