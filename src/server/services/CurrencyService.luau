local Players = game:GetService("Players")

local PlotService = require(script.Parent.PlotService)

local CurrencyService = {}

local STARTING_MONEY = 500

local function setupLeaderstats(player)
	local leaderstats  = Instance.new("Folder")
	leaderstats.Name   = "leaderstats"
	leaderstats.Parent = player

	local money       = Instance.new("IntValue")
	money.Name        = "Money"
	money.Value       = STARTING_MONEY
	money.Parent      = leaderstats
end

function CurrencyService:init()
	Players.PlayerAdded:Connect(setupLeaderstats)

	-- Cobre players que entraram antes do init (edge case em Studio)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(setupLeaderstats, player)
	end
end

function CurrencyService:getMoney(player)
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Money") and ls.Money.Value or 0
end

function CurrencyService:addMoney(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Money") then
		ls.Money.Value += amount
	end
end

-- Credita `amount` exclusivamente para o dono do plot.
-- Ignoramos quem deu o golpe final — a recompensa pertence a quem defende aquela base.
function CurrencyService:rewardForPlot(plot, amount: number)
	local userId = PlotService:getOwnerUserId(plot)
	if not userId then return end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self:addMoney(player, amount)
	end
end

-- Retorna true e debita se tiver saldo. Retorna false sem alterar nada caso contrário.
function CurrencyService:spendMoney(player, amount)
	if self:getMoney(player) < amount then
		return false
	end
	local ls = player:FindFirstChild("leaderstats")
	ls.Money.Value -= amount
	return true
end

return CurrencyService
