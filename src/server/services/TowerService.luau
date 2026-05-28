local RunService = game:GetService("RunService")

local TowerClass     = require(script.Parent.Parent.classes.TowerClass)
local EnemyService   = require(script.Parent.EnemyService)
local PhysicsService = require(script.Parent.PhysicsService)

local TowerService = {}

-- { [Model]: { obj: TowerClass, plot: Model } }
local activeTowers = {}

RunService.Heartbeat:Connect(function(dt)
	for model, info in pairs(activeTowers) do
		if not model.Parent then
			activeTowers[model] = nil
			continue
		end

		local plotEnemies = EnemyService:getActiveForPlot(info.plot)
		info.obj:update(dt, plotEnemies)

		if info.obj._dead then
			activeTowers[model] = nil
			if model.Parent then model:Destroy() end
		end
	end
end)

function TowerService:registerTower(towerModel: Model, towerName: string, level: number?, plot: Model?)
	local ok, result = pcall(TowerClass.new, towerModel, towerName, level or 1)
	if not ok then
		warn(("[TowerService] Falha ao registrar '%s': %s"):format(towerName, tostring(result)))
		return
	end
	activeTowers[towerModel] = { obj = result, plot = plot }
	PhysicsService:assignToGroup(towerModel, "Towers")
end

function TowerService:unregisterTower(towerModel: Model)
	activeTowers[towerModel] = nil
end

function TowerService:getActive()
	local out = {}
	for model, info in pairs(activeTowers) do
		out[model] = info.obj
	end
	return out
end

function TowerService:getActiveForPlot(plot)
	local out = {}
	for model, info in pairs(activeTowers) do
		if info.plot == plot then out[model] = info.obj end
	end
	return out
end

function TowerService:init()
	EnemyService:setTowerProvider(function(plot) return TowerService:getActiveForPlot(plot) end)
	print("[TowerService] Pronto.")
end

return TowerService
