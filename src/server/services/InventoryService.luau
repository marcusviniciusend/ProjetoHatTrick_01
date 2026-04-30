local Players = game:GetService("Players")

local InventoryService = {}

-- { [userId: number]: { [towerName: string]: count: number } }
-- Sessão em memória: persiste entre rounds do mesmo servidor, limpa ao sair.
local inventory: { [number]: { [string]: number } } = {}

function InventoryService:add(player: Player, towerName: string)
	local uid = player.UserId
	if not inventory[uid] then inventory[uid] = {} end
	inventory[uid][towerName] = (inventory[uid][towerName] or 0) + 1
	print(("[InventoryService] '%s' recebeu '%s' — total: %d"):format(
		player.Name, towerName, inventory[uid][towerName]))
end

-- Consome 1 unidade. Retorna true se tinha estoque, false se não tinha.
function InventoryService:consume(player: Player, towerName: string): boolean
	local uid = player.UserId
	local inv = inventory[uid]
	if not inv or (inv[towerName] or 0) <= 0 then return false end
	inv[towerName] -= 1
	return true
end

function InventoryService:getCount(player: Player, towerName: string): number
	local uid = player.UserId
	local inv = inventory[uid]
	return inv and (inv[towerName] or 0) or 0
end

function InventoryService:init()
	Players.PlayerRemoving:Connect(function(player)
		inventory[player.UserId] = nil
	end)
	print("[InventoryService] Pronto.")
end

return InventoryService
