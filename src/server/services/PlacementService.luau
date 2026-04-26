local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")

local Shared          = ReplicatedStorage:WaitForChild("Shared")
local TowerStats      = require(Shared.configs.TowerStats)
local Remotes         = require(Shared.network.Remotes)

local PlotService     = require(script.Parent.PlotService)
local CurrencyService = require(script.Parent.CurrencyService)
local TowerService    = require(script.Parent.TowerService)

local PlacementService = {}

local towersFolder = nil
local placedTowers = {}  -- { [model] = { owner = userId, towerName = string } }

-- ── Helpers ────────────────────────────────────────────────────────────────

local function log(msg, ...)  print(("[PlacementService] " .. msg):format(...)) end
local function warn_(msg, ...) warn(("[PlacementService] " .. msg):format(...)) end

local function tryPlace(player, towerName, position)
	local stats = TowerStats[towerName]
	if not stats then
		warn_("Torre inválida: '%s'", towerName)
		return
	end

	if not PlotService:isInsidePlot(player, position) then
		warn_("'%s' tentou colocar fora do plot", player.Name)
		return
	end

	if not CurrencyService:spendMoney(player, stats.Price) then
		warn_("'%s' sem saldo para '%s' ($%d)", player.Name, towerName, stats.Price)
		return
	end

	if not towersFolder then
		warn_("ServerStorage.towers não encontrado — devolvendo saldo")
		CurrencyService:addMoney(player, stats.Price)
		return
	end

	local template = towersFolder:FindFirstChild(towerName)
	if not template then
		warn_("Modelo '%s' não encontrado em ServerStorage.towers — devolvendo saldo", towerName)
		CurrencyService:addMoney(player, stats.Price)
		return
	end

	local clone = template:Clone()

	if clone:IsA("Model") and clone.PrimaryPart then
		clone:SetPrimaryPartCFrame(CFrame.new(position))
	elseif clone:IsA("BasePart") then
		clone.Position = position
	end

	clone.Parent = Workspace

	placedTowers[clone] = { owner = player.UserId, towerName = towerName }
	TowerService:registerTower(clone, towerName)

	log("'%s' colocou '%s' em %s", player.Name, towerName, tostring(position))
end

local function trySell(player, tower)
	local info = placedTowers[tower]
	if not info then
		warn_("Torre inválida ou já removida")
		return
	end
	if info.owner ~= player.UserId then
		warn_("'%s' tentou vender torre de outro player", player.Name)
		return
	end

	local stats  = TowerStats[info.towerName]
	local refund = stats and math.floor(stats.Price * 0.5) or 0

	TowerService:unregisterTower(tower)
	placedTowers[tower] = nil
	tower:Destroy()

	CurrencyService:addMoney(player, refund)
	log("'%s' vendeu '%s' por $%d", player.Name, info.towerName, refund)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function PlacementService:init()
	towersFolder = ServerStorage:FindFirstChild("towers")
	if not towersFolder then
		warn_("ServerStorage.towers não encontrado — crie a pasta no Studio com os modelos")
	end

	Remotes.PlaceTower.OnServerEvent:Connect(tryPlace)
	Remotes.SellTower.OnServerEvent:Connect(trySell)
end

return PlacementService
