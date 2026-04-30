local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage.Shared.network.Remotes)
local DataService = require(script.Parent.DataService)

local InventoryService = {}

-- Retorna a lista de torres do perfil, ou nil se o perfil ainda não carregou.
local function getTowers(player: Player): { string }?
	local profile = DataService:GetProfile(player)
	return profile and profile.Inventory.Towers
end

function InventoryService:add(player: Player, towerName: string)
	local towers = getTowers(player)
	if not towers then return end
	table.insert(towers, towerName)
	print(("[InventoryService] '%s' recebeu '%s' — total: %d"):format(
		player.Name, towerName, self:getCount(player, towerName)))
end

-- Consome 1 unidade. Retorna true se tinha estoque, false se não tinha.
function InventoryService:consume(player: Player, towerName: string): boolean
	local towers = getTowers(player)
	if not towers then return false end
	for i, name in ipairs(towers) do
		if name == towerName then
			table.remove(towers, i)
			return true
		end
	end
	return false
end

function InventoryService:getCount(player: Player, towerName: string): number
	local towers = getTowers(player)
	if not towers then return 0 end
	local count = 0
	for _, name in ipairs(towers) do
		if name == towerName then count += 1 end
	end
	return count
end

function InventoryService:init()
	Remotes.GetInventory.OnServerInvoke = function(player: Player)
		return getTowers(player) or {}
	end
	print("[InventoryService] Pronto.")
end

return InventoryService
