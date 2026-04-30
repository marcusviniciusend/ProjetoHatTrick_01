local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Shared          = ReplicatedStorage:WaitForChild("Shared")
local TowerStats      = require(Shared.configs.TowerStats)
local Remotes         = require(Shared.network.Remotes)

local PlotService       = require(script.Parent.PlotService)
local CurrencyService   = require(script.Parent.CurrencyService)
local TowerService      = require(script.Parent.TowerService)
local InventoryService  = require(script.Parent.InventoryService)

local PlacementService = {}

-- Torres em ReplicatedStorage para que o cliente possa clonar o preview 3D
local towersFolder   = nil
local placedTowers   = {}  -- { [model] = { owner = userId, towerName = string, level = number } }
local savedSnapshot  = {}  -- { { towerName, level, cframe, ownerUserId } }
local _phaseProvider = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

local function log(msg, ...)   print(("[PlacementService] " .. msg):format(...)) end
local function warn_(msg, ...) warn(("[PlacementService] "  .. msg):format(...)) end

local function anchorClone(clone)
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored   = true
			desc.CanCollide = true
		end
	end
	if clone.PrimaryPart then
		clone.PrimaryPart.Anchored   = true
		clone.PrimaryPart.CanCollide = true
	end
end

local function spawnTower(clone, towerName, cframe, ownerUserId, level)
	anchorClone(clone)

	if clone:IsA("Model") and clone.PrimaryPart then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		(clone :: BasePart).CFrame = cframe
	end

	clone.Parent = Workspace

	placedTowers[clone] = { owner = ownerUserId, towerName = towerName, level = level }
	clone.Destroying:Connect(function() placedTowers[clone] = nil end)

	TowerService:registerTower(clone, towerName, level)
end

-- ── Placement ──────────────────────────────────────────────────────────────

local function tryPlace(player, towerName, position)
	if _phaseProvider and _phaseProvider() ~= "BuildPhase" then
		warn_("'%s' tentou construir durante CombatPhase", player.Name)
		return
	end

	local stats = TowerStats[towerName]
	if not stats then
		warn_("Torre inválida: '%s'", towerName)
		return
	end

	if not PlotService:isInsidePlot(player, position) then
		warn_("'%s' tentou colocar fora do plot", player.Name)
		return
	end

	-- Verifica inventário primeiro; só cobra se não tiver unidade comprada na loja
	local fromInventory = InventoryService:consume(player, towerName)
	if not fromInventory then
		if not CurrencyService:spendMoney(player, stats.BasePrice) then
			warn_("'%s' sem saldo para '%s' ($%d)", player.Name, towerName, stats.BasePrice)
			return
		end
	end

	if not towersFolder then
		warn_("Pasta de torres não encontrada — devolvendo saldo")
		if not fromInventory then CurrencyService:addMoney(player, stats.BasePrice) end
		return
	end

	local template = towersFolder:FindFirstChild(towerName)
	if not template then
		warn_("Modelo '%s' não encontrado — devolvendo saldo", towerName)
		if not fromInventory then CurrencyService:addMoney(player, stats.BasePrice) end
		return
	end

	local clone = template:Clone()
	spawnTower(clone, towerName, CFrame.new(position), player.UserId, 1)
	log("'%s' colocou '%s' em %s", player.Name, towerName, tostring(position))
end

-- ── Ação na torre (Upgrade / Sell) ─────────────────────────────────────────

local function handleTowerAction(player: Player, tower: Model, action: string): boolean
	if _phaseProvider and _phaseProvider() ~= "BuildPhase" then
		warn_("'%s' tentou '%s' durante CombatPhase", player.Name, action)
		return false
	end

	local info = placedTowers[tower]
	if not info then
		warn_("Torre inválida ou já removida")
		return false
	end

	if info.owner ~= player.UserId then
		warn_("'%s' tentou agir em torre de outro player", player.Name)
		return false
	end

	if action == "Upgrade" then
		local towerObj = TowerService:getActive()[tower]
		if not towerObj then return false end

		local cost = towerObj:getUpgradeCost()
		if not cost then
			warn_("'%s' tentou upar torre já no nível máximo", player.Name)
			return false
		end

		if not CurrencyService:spendMoney(player, cost) then
			warn_("'%s' sem saldo para upgrade ($%d)", player.Name, cost)
			return false
		end

		local ok = towerObj:upgrade()
		if not ok then
			CurrencyService:addMoney(player, cost)
			return false
		end

		-- Persiste nível no placedTowers para snapshot correto no próximo Start
		info.level = towerObj.level
		log("'%s' upou '%s' para Level %d", player.Name, info.towerName, towerObj.level)
		return true

	elseif action == "Sell" then
		local stats  = TowerStats[info.towerName]
		local refund = stats and math.floor(stats.BasePrice * 0.5) or 0

		TowerService:unregisterTower(tower)
		placedTowers[tower] = nil
		tower:Destroy()

		CurrencyService:addMoney(player, refund)
		log("'%s' vendeu '%s' por $%d", player.Name, info.towerName, refund)
		return true
	end

	warn_("Ação desconhecida: '%s'", action)
	return false
end

-- ── Snapshot ───────────────────────────────────────────────────────────────

function PlacementService:saveSnapshot()
	savedSnapshot = {}
	for model, info in pairs(placedTowers) do
		if model.Parent then
			table.insert(savedSnapshot, {
				towerName   = info.towerName,
				level       = info.level or 1,
				cframe      = model:GetPivot(),
				ownerUserId = info.owner,
			})
		end
	end
	log("Snapshot salvo: %d torre(s)", #savedSnapshot)
end

function PlacementService:restoreSnapshot()
	local toDestroy = {}
	for model in pairs(placedTowers) do
		table.insert(toDestroy, model)
	end
	placedTowers = {}

	for _, model in ipairs(toDestroy) do
		TowerService:unregisterTower(model)
		if model.Parent then model:Destroy() end
	end

	if not towersFolder then return end

	for _, data in ipairs(savedSnapshot) do
		local template = towersFolder:FindFirstChild(data.towerName)
		if not template then continue end
		local clone = template:Clone()
		spawnTower(clone, data.towerName, data.cframe, data.ownerUserId, data.level)
	end

	log("Snapshot restaurado: %d torre(s)", #savedSnapshot)
end

-- ── Remoção por dono ───────────────────────────────────────────────────────

function PlacementService:destroyTowersForPlayer(ownerUserId: number)
	local toDestroy = {}
	for model, info in pairs(placedTowers) do
		if info.owner == ownerUserId then
			table.insert(toDestroy, model)
		end
	end
	for _, model in ipairs(toDestroy) do
		TowerService:unregisterTower(model)
		placedTowers[model] = nil
		if model.Parent then model:Destroy() end
	end
	log("Torres do userId %d removidas (%d)", ownerUserId, #toDestroy)
end

-- ── Phase provider ─────────────────────────────────────────────────────────

function PlacementService:setPhaseProvider(fn)
	_phaseProvider = fn
end

-- ── Init ───────────────────────────────────────────────────────────────────

function PlacementService:init()
	-- Torres em ReplicatedStorage (acessível também ao cliente para preview 3D)
	towersFolder = ReplicatedStorage:FindFirstChild("towers")
	if not towersFolder then
		warn_("ReplicatedStorage.towers não encontrado — mova a pasta de torres para ReplicatedStorage")
	end

	Remotes.PlaceTower.OnServerEvent:Connect(tryPlace)

	-- Unifica Upgrade e Sell numa única RemoteFunction com retorno booleano
	Remotes.RequestTowerAction.OnServerInvoke = function(player, tower, action)
		return handleTowerAction(player, tower, action)
	end
end

return PlacementService
