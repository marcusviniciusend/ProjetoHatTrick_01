local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")

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
local placedTowers   = {}  -- { [model] = { owner = userId, towerName = string, level = number, quad = BasePart } }
local savedSnapshots = {}  -- { [ownerUserId] = { { towerName, level, cframe, ownerUserId, quad } } }
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

local function spawnTower(clone, towerName, cframe, ownerUserId, level, quad)
	anchorClone(clone)

	if clone:IsA("Model") and clone.PrimaryPart then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		(clone :: BasePart).CFrame = cframe
	end

	clone.Parent = Workspace

	placedTowers[clone] = { owner = ownerUserId, towerName = towerName, level = level, quad = quad }
	clone.Destroying:Connect(function() placedTowers[clone] = nil end)

	if quad then quad:SetAttribute("Ocupado", true) end
	local player = Players:GetPlayerByUserId(ownerUserId)
	local plot   = player and PlotService:getPlot(player) or nil
	TowerService:registerTower(clone, towerName, level, plot)
end

-- ── Placement ──────────────────────────────────────────────────────────────

local function tryPlace(player, towerName, quad): boolean
	if _phaseProvider and _phaseProvider(player) ~= "BuildPhase" then
		warn_("'%s' tentou construir durante CombatPhase", player.Name)
		return false
	end

	-- Anti-hack: quad deve ser um BasePart "plotQuad" válido e desocupado
	if not (typeof(quad) == "Instance" and quad:IsA("BasePart") and quad.Name == "plotQuad") then
		warn_("'%s' enviou quad inválido", player.Name)
		return false
	end
	if quad:GetAttribute("Ocupado") == true then
		warn_("'%s' tentou colocar em quad já ocupado", player.Name)
		return false
	end

	local stats = TowerStats[towerName]
	if not stats then
		warn_("Torre inválida: '%s'", towerName)
		return false
	end

	if not PlotService:isInsidePlot(player, quad.Position) then
		warn_("'%s' tentou colocar fora do seu plot", player.Name)
		return false
	end

	-- Somente torres do inventário podem ser construídas
	if not InventoryService:consume(player, towerName) then
		warn_("'%s' não tem '%s' no inventário", player.Name, towerName)
		return false
	end

	if not towersFolder then
		warn_("Pasta de torres não encontrada — devolvendo item")
		InventoryService:add(player, towerName)
		return false
	end

	local template = towersFolder:FindFirstChild(towerName)
	if not template then
		warn_("Modelo '%s' não encontrado — devolvendo item", towerName)
		InventoryService:add(player, towerName)
		return false
	end

	local position = Vector3.new(quad.Position.X, quad.Position.Y + (quad.Size.Y / 2), quad.Position.Z)
	local clone    = template:Clone()
	spawnTower(clone, towerName, CFrame.new(position), player.UserId, 1, quad)
	log("'%s' colocou '%s' em %s", player.Name, towerName, tostring(quad.Name))
	return true
end

-- ── Ação na torre (Upgrade / Sell) ─────────────────────────────────────────

local function handleTowerAction(player: Player, tower: Model, action: string): boolean
	if _phaseProvider and _phaseProvider(player) ~= "BuildPhase" then
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
		if info.quad then info.quad:SetAttribute("Ocupado", false) end
		placedTowers[tower] = nil
		tower:Destroy()

		CurrencyService:addMoney(player, refund)
		log("'%s' vendeu '%s' por $%d", player.Name, info.towerName, refund)
		return true

	elseif action == "Store" then
		TowerService:unregisterTower(tower)
		if info.quad then info.quad:SetAttribute("Ocupado", false) end
		placedTowers[tower] = nil
		tower:Destroy()

		InventoryService:add(player, info.towerName)
		log("'%s' guardou '%s' no inventário", player.Name, info.towerName)
		return true
	end

	warn_("Ação desconhecida: '%s'", action)
	return false
end

-- ── Snapshot ───────────────────────────────────────────────────────────────

function PlacementService:saveSnapshot(ownerUserId: number)
	savedSnapshots[ownerUserId] = {}
	for model, info in pairs(placedTowers) do
		if model.Parent and info.owner == ownerUserId then
			table.insert(savedSnapshots[ownerUserId], {
				towerName   = info.towerName,
				level       = info.level or 1,
				cframe      = model:GetPivot(),
				ownerUserId = info.owner,
				quad        = info.quad,
			})
		end
	end
	log("Snapshot salvo para userId %d: %d torre(s)", ownerUserId, #savedSnapshots[ownerUserId])
end

function PlacementService:restoreSnapshot(ownerUserId: number)
	local snapshot = savedSnapshots[ownerUserId] or {}

	local toDestroy = {}
	for model, info in pairs(placedTowers) do
		if info.owner == ownerUserId then
			table.insert(toDestroy, model)
		end
	end
	for _, model in ipairs(toDestroy) do
		local info = placedTowers[model]
		TowerService:unregisterTower(model)
		if info and info.quad then info.quad:SetAttribute("Ocupado", false) end
		placedTowers[model] = nil
		if model.Parent then model:Destroy() end
	end

	if not towersFolder then return end

	for _, data in ipairs(snapshot) do
		local template = towersFolder:FindFirstChild(data.towerName)
		if not template then continue end
		local clone = template:Clone()
		spawnTower(clone, data.towerName, data.cframe, data.ownerUserId, data.level, data.quad)
	end

	log("Snapshot restaurado para userId %d: %d torre(s)", ownerUserId, #snapshot)
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
		local info = placedTowers[model]
		TowerService:unregisterTower(model)
		if info and info.quad then info.quad:SetAttribute("Ocupado", false) end
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

	-- RemoteFunction: retorna true/false ao cliente; pcall evita que erros internos
	-- propaguem como exceção e travam o InvokeServer do cliente indefinidamente.
	Remotes.PlaceTower.OnServerInvoke = function(player, towerName, quad)
		local ok, result = pcall(tryPlace, player, towerName, quad)
		if not ok then
			warn_("Erro interno em tryPlace: %s", tostring(result))
			return false
		end
		return result
	end

	-- Unifica Upgrade e Sell numa única RemoteFunction com retorno booleano
	Remotes.RequestTowerAction.OnServerInvoke = function(player, tower, action)
		return handleTowerAction(player, tower, action)
	end
end

return PlacementService
