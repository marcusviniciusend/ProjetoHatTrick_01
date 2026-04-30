local Players = game:GetService("Players")

local PlotService   = require(script.Parent.PlotService)
local DataService   = require(script.Parent.DataService)

local CurrencyService = {}

local moneyValues = {}  -- { [player] = IntValue } — cache para evitar FindFirstChild por chamada

local function syncLeaderstats(player: Player, coins: number)
	local mv = moneyValues[player]
	if mv then mv.Value = coins end
end

local function setupLeaderstats(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then return end

	local leaderstats  = Instance.new("Folder")
	leaderstats.Name   = "leaderstats"
	leaderstats.Parent = player

	local money       = Instance.new("IntValue")
	money.Name        = "Money"
	money.Value       = profile.Currency.Coins
	money.Parent      = leaderstats

	moneyValues[player] = money
end

function CurrencyService:init()
	-- ProfileLoaded garante que o perfil já está em memória quando setupLeaderstats roda,
	-- eliminando a necessidade de polling (waitForProfile).
	DataService.ProfileLoaded.Event:Connect(setupLeaderstats)

	-- Limpa cache ao sair para não vazar memória
	Players.PlayerRemoving:Connect(function(player)
		moneyValues[player] = nil
	end)

	-- Edge case: Studio Play Solo — jogador pode já estar presente ao init rodar
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if DataService:GetProfile(player) then
				setupLeaderstats(player)
			end
		end)
	end
end

function CurrencyService:getMoney(player: Player): number
	local profile = DataService:GetProfile(player)
	return profile and profile.Currency.Coins or 0
end

function CurrencyService:addMoney(player: Player, amount: number)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	profile.Currency.Coins += amount
	syncLeaderstats(player, profile.Currency.Coins)
end

-- Credita `amount` exclusivamente para o dono do plot.
function CurrencyService:rewardForPlot(plot, amount: number)
	local userId = PlotService:getOwnerUserId(plot)
	if not userId then return end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self:addMoney(player, amount)
	end
end

-- Retorna true e debita se tiver saldo. Retorna false sem alterar nada caso contrário.
function CurrencyService:spendMoney(player: Player, amount: number): boolean
	local profile = DataService:GetProfile(player)
	if not profile then return false end
	if profile.Currency.Coins < amount then return false end
	profile.Currency.Coins -= amount
	syncLeaderstats(player, profile.Currency.Coins)
	return true
end

return CurrencyService
