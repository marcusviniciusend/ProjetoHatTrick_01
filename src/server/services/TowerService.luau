local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStats    = require(ReplicatedStorage.Shared.configs.TowerStats)
local EnemyService  = require(script.Parent.EnemyService)

local TowerService = {}

-- { [towerModel] = { lastAttack = tick, stats = TowerStats entry } }
local activeTowers = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function getTowerPosition(tower)
	if tower:IsA("Model") and tower.PrimaryPart then
		return tower.PrimaryPart.Position
	elseif tower:IsA("BasePart") then
		return tower.Position
	end
	return nil
end

local function findNearestEnemy(towerPos, range)
	local nearest, nearestDist = nil, math.huge

	for enemy in pairs(EnemyService:getActive()) do
		if not enemy.Parent then continue end

		local primary = enemy.PrimaryPart
		if not primary then continue end

		local dist = (primary.Position - towerPos).Magnitude
		if dist <= range and dist < nearestDist then
			nearest     = enemy
			nearestDist = dist
		end
	end

	return nearest
end

-- ── Loop de ataque ─────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
	local now = tick()

	for tower, state in pairs(activeTowers) do
		-- Remove torres que foram destruídas (vendidas, etc.)
		if not tower.Parent then
			activeTowers[tower] = nil
			continue
		end

		local stats = state.stats
		if not stats.Damage or stats.Damage <= 0 then continue end  -- torres de suporte

		local cooldown = 1 / stats.AttackSpeed
		if now - state.lastAttack < cooldown then continue end

		local towerPos = getTowerPosition(tower)
		if not towerPos then continue end

		local target = findNearestEnemy(towerPos, stats.Range)
		if target then
			state.lastAttack = now
			EnemyService:damage(target, stats.Damage)
		end
	end
end)

-- ── API pública ────────────────────────────────────────────────────────────

-- Chamado pelo PlacementService quando uma torre é colocada
function TowerService:registerTower(towerModel, towerName)
	local stats = TowerStats[towerName]
	if not stats then
		warn(("[TowerService] Stats não encontrados para '%s'"):format(towerName))
		return
	end

	activeTowers[towerModel] = {
		lastAttack = 0,
		stats      = stats,
	}
end

function TowerService:unregisterTower(towerModel)
	activeTowers[towerModel] = nil
end

function TowerService:init()
	-- O registro de torres acontece via TowerService:registerTower()
	-- chamado pelo PlacementService ao colocar cada torre
	print("[TowerService] Pronto.")
end

return TowerService
