local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes          = require(ReplicatedStorage.Shared.network.Remotes)
local TowerStats       = require(ReplicatedStorage.Shared.configs.TowerStats)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService  = require(script.Parent.CurrencyService)

local SellService = {}

local function handleSell(player: Player, itemCategory: string, itemName: string): boolean
	if itemCategory == "Tower" then
		if not InventoryService:consume(player, itemName) then
			warn(("[SellService] '%s' não tem '%s' no inventário"):format(player.Name, itemName))
			return false
		end

		local data = TowerStats[itemName]
		if not data then
			warn(("[SellService] TowerStats não encontrado para '%s' — item consumido sem reembolso"):format(itemName))
			return true
		end

		local refund = math.floor(data.BasePrice * 0.5)
		CurrencyService:addMoney(player, refund)
		print(("[SellService] '%s' vendeu '%s' por $%d"):format(player.Name, itemName, refund))
		return true

	elseif itemCategory == "Weapon" then
		-- TODO: Implementar futuramente
		warn("[SellService] Categoria 'Weapon' ainda não implementada")
		return false
	end

	warn(("[SellService] Categoria desconhecida: '%s'"):format(tostring(itemCategory)))
	return false
end

function SellService:init()
	Remotes.RequestSellItem.OnServerInvoke = function(player: Player, itemCategory: string, itemName: string)
		local ok, result = pcall(handleSell, player, itemCategory, itemName)
		if not ok then
			warn(("[SellService] Erro interno: %s"):format(tostring(result)))
			return false
		end
		return result
	end
	print("[SellService] Pronto.")
end

return SellService
