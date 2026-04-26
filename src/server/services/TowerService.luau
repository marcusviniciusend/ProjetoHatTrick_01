local RunService = game:GetService("RunService")

local TowerClass   = require(script.Parent.Parent.classes.TowerClass)
local EnemyService = require(script.Parent.EnemyService)

local TowerService = {}

local activeTowers = {}  -- { [Model]: TowerClass }

RunService.Heartbeat:Connect(function(dt)
	local activeEnemies = EnemyService:getActive()

	for model, towerObj in pairs(activeTowers) do
		if not model.Parent then
			activeTowers[model] = nil
			continue
		end
		towerObj:update(dt, activeEnemies)
	end
end)

function TowerService:registerTower(towerModel: Model, towerName: string, level: number?)
	local ok, result = pcall(TowerClass.new, towerModel, towerName, level or 1)
	if not ok then
		warn(("[TowerService] Falha ao registrar '%s': %s"):format(towerName, tostring(result)))
		return
	end
	activeTowers[towerModel] = result
end

function TowerService:unregisterTower(towerModel: Model)
	activeTowers[towerModel] = nil
end

function TowerService:init()
	print("[TowerService] Pronto.")
end

return TowerService
